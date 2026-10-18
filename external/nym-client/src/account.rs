// GPL-3.0-only: integrates the official NymVPN account controller.
use async_trait::async_trait;
use nym_bandwidth_controller::{TicketType, BandwidthController, requests::BandwidthControllerRequestSender};
use nym_offline_monitor::{Connectivity, ConnectivityMonitor};
use nym_sdk::{mixnet::StoragePaths, UserAgent};
use nym_vpn_account_controller::{AccountController, AccountControllerConfig, NyxdClient};
use nym_vpn_api_client::{VpnApiClient, types::VpnAccount};
use nym_vpn_lib_types::{AccountControllerState, Mnemonic, StorableAccount, StoredAccountMode, VpnAccountSummary};
use nym_vpn_network_config::NetworkCache;
use nym_vpn_store::{account::{AccountInformationStorage, ephemeral::{InMemoryAccountStorage, InMemoryAccountStorageError}},
    account_summary::{AccountSummaryStorage, ephemeral::InMemoryAccountSummaryStorage},
    keys::device::{DeviceKeyStore, DeviceKeys, DeviceKeysPaths, OnDiskKeys, OnDiskKeysError}};
use sha2::{Digest, Sha256};
use std::{convert::Infallible, path::{Path, PathBuf}};
use tokio_util::sync::CancellationToken;
use crate::Failure;

// API calls detect actual network failures. No system route manager is created.
struct ConnectivityProbe;
#[async_trait]
impl ConnectivityMonitor for ConnectivityProbe {
    async fn connectivity(&'async_trait self) -> Connectivity { Connectivity::PresumeOnline }
    async fn next(&'async_trait mut self) -> Option<Connectivity> { std::future::pending().await }
}

// Mnemonic only in memory (received from the wallet through stdin). Persistent
// device keys and ticketbooks are exclusively in the wallet's private directory.
struct AccountStore {
    account: InMemoryAccountStorage,
    keys: OnDiskKeys,
    summary: InMemoryAccountSummaryStorage,
}
impl nym_vpn_store::VpnStorage for AccountStore {}
#[async_trait]
impl AccountInformationStorage for AccountStore {
    type StorageError = InMemoryAccountStorageError;
    async fn load_account(&self) -> Result<Option<StorableAccount>, Self::StorageError> { self.account.load_account().await }
    async fn store_account(&self, a: StorableAccount) -> Result<(), Self::StorageError> { self.account.store_account(a).await }
    async fn remove_account(&self) -> Result<(), Self::StorageError> { self.account.remove_account().await }
}
#[async_trait]
impl DeviceKeyStore for AccountStore {
    type StorageError = OnDiskKeysError;
    async fn load_keys(&self) -> Result<Option<DeviceKeys>, Self::StorageError> { self.keys.load_keys().await }
    async fn store_keys(&self, k: &DeviceKeys) -> Result<(), Self::StorageError> { self.keys.store_keys(k).await }
    async fn init_keys(&self, s: Option<[u8;32]>) -> Result<(), Self::StorageError> { self.keys.init_keys(s).await }
    async fn reset_keys(&self, s: Option<[u8;32]>) -> Result<(), Self::StorageError> { self.keys.reset_keys(s).await }
    async fn remove_keys(&self) -> Result<(), Self::StorageError> { self.keys.remove_keys().await }
}
#[async_trait]
impl AccountSummaryStorage for AccountStore {
    type StorageError = Infallible;
    async fn load_summary(&self) -> Result<Option<VpnAccountSummary>, Self::StorageError> { self.summary.load_summary().await }
    async fn store_summary(&self, s: VpnAccountSummary) -> Result<(), Self::StorageError> { self.summary.store_summary(s).await }
    async fn remove_summary(&self) -> Result<(), Self::StorageError> { self.summary.remove_summary().await }
}

pub struct Access {
    pub bandwidth: BandwidthControllerRequestSender,
    pub network: nym_vpn_network_config::Network,
    pub device: String,
    _shutdown: tokio_util::sync::DropGuard,
}

pub fn parse_phrase(words: &str) -> Result<Mnemonic, Failure> {
    if words.split_whitespace().count() != 24 { return Err("Enter the 24 words of your NymVPN account".into()); }
    Mnemonic::parse(words).map_err(|_| "Invalid NymVPN recovery phrase".into())
}

async fn initialise_store(dir: &Path, account: StorableAccount) -> Result<AccountStore, Failure> {
    let store = AccountStore { account: InMemoryAccountStorage::default(),
        keys: OnDiskKeys::new(DeviceKeysPaths::new(dir)), summary: InMemoryAccountSummaryStorage::default() };
    // Initialise once; retain this wallet device across reconnects.
    store.init_keys(None).await?;
    store.store_account(account).await?;
    Ok(store)
}

pub async fn authenticate(words: &str, root: &Path) -> Result<Access, Failure> {
    let account = StorableAccount { mnemonic: parse_phrase(words)?, mode: StoredAccountMode::Api };
    let account_id = VpnAccount::try_from(account.clone())?.id();
    let dir: PathBuf = root.join(Sha256::digest(account_id.as_bytes()).iter().map(|b| format!("{b:02x}")).collect::<String>());
    std::fs::create_dir_all(&dir)?;
    #[cfg(unix)] {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(root, std::fs::Permissions::from_mode(0o700))?;
        std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700))?;
    }
    let user_agent = UserAgent { application: "XMR-wallet-Nym".into(), version: "0.2.0".into(),
        platform: std::env::consts::OS.into(), git_commit: "nym-vpn-v2026.13.0".into() };
    let mut cache = NetworkCache::new(root.join("network"), "mainnet", Some(user_agent.clone())).await?;
    cache.fetch_if_stale().await?;
    let network = *cache.network()?;
    let paths = StoragePaths::new_from_dir(&dir)?;
    let storage = paths.persistent_credential_storage().await?;
    let bandwidth = BandwidthController::new(storage);
    let sender = bandwidth.get_request_sender();
    let shutdown = CancellationToken::new();
    tokio::spawn(bandwidth.run(shutdown.child_token().into()));
    let store = initialise_store(&dir, account).await?;
    let api = VpnApiClient::from_network(network.nym_network_details(), Some(user_agent)).await?;
    let controller = AccountController::new(api, NyxdClient::new(&network), AccountControllerConfig {
        data_dir: dir, storage_paths: paths, network_env: network.clone()
    }, store, ConnectivityProbe, sender.clone(), shutdown.child_token()).await?;
    let state = controller.get_state_receiver();
    let commands = controller.get_command_sender();
    let mut updates = state.subscribe();
    tokio::spawn(controller.run());
    loop {
        match state.get_state() {
            AccountControllerState::ReadyToConnect => break,
            AccountControllerState::Syncing => updates.changed().await?,
            AccountControllerState::PendingSubscription => return Err("Your NymVPN subscription is pending".into()),
            AccountControllerState::Error(reason) => return Err(format!("NymVPN account: {reason}").into()),
            AccountControllerState::Offline => return Err("NymVPN authentication is offline".into()),
            _ => return Err("A valid NymVPN subscription account is required".into()),
        }
    }
    // Account readiness installs the fetcher, but ticket downloads are asynchronous.
    // Match the official tunnel's separate readiness barrier before gateway registration.
    crate::event(serde_json::json!({"event":"credentials"}));
    tokio::time::timeout(std::time::Duration::from_secs(120),
        sender.wait_for_ticketbooks(vec![TicketType::V1MixnetEntry]))
        .await.map_err(|_| "Nym ha tardado demasiado en preparar las credenciales de ancho de banda. Vuelve a conectar.")?
        .map_err(|e| format!("No se pudieron preparar las credenciales de NymVPN: {e}"))?;
    let device = commands.get_device_identity().await?.unwrap_or_default();
    Ok(Access { bandwidth: sender, network, device, _shutdown: shutdown.drop_guard() })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn fresh_device_exists_and_reconnect_keeps_identity() {
        let dir = std::env::temp_dir().join(format!("xmr-nym-device-test-{}", rand::random::<u64>()));
        std::fs::create_dir_all(&dir).unwrap();
        let words = format!("{}art", "abandon ".repeat(23));
        let account = StorableAccount { mnemonic: parse_phrase(&words).unwrap(), mode: StoredAccountMode::Api };
        let first = initialise_store(&dir, account.clone()).await.unwrap();
        let first_keys = first.load_keys().await.unwrap().expect("fresh device keys");
        let identity = nym_vpn_api_client::types::Device::from(first_keys.device_keypair()).identity_key().to_owned();
        drop(first);
        let second = initialise_store(&dir, account).await.unwrap();
        let second_keys = second.load_keys().await.unwrap().unwrap();
        assert_eq!(&identity, nym_vpn_api_client::types::Device::from(second_keys.device_keypair()).identity_key());
        std::fs::remove_dir_all(dir).unwrap();
    }
}
