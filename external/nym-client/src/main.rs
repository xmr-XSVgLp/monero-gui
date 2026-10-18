//! Wallet-owned authenticated NymVPN account + mixnet session. GPL-3.0-only.
mod account;
use nym_sdk::mixnet::{MixnetClientBuilder, Socks5};
use nym_validator_client::nym_api::NymApiClientExt;
use rand::seq::IndexedRandom;
use serde_json::json;
use std::{io::{self, Write}, net::SocketAddr, path::Path, time::Duration};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use zeroize::Zeroizing;
type Failure = Box<dyn std::error::Error + Send + Sync>;

fn event(value: serde_json::Value) {
    println!("{value}");
    let _ = io::stdout().flush();
}
async fn stop_requested() {
    let mut input = tokio::io::stdin();
    let mut byte = [0];
    tokio::select! { _ = input.read(&mut byte) => {}, _ = tokio::signal::ctrl_c() => {} }
}
async fn read_phrase() -> Result<Zeroizing<String>, Failure> {
    let mut input = tokio::io::stdin();
    let mut line = Zeroizing::new(Vec::new());
    loop {
        let byte = input.read_u8().await.map_err(|_| "NymVPN login was cancelled")?;
        if byte == b'\n' { break; }
        if line.len() >= 2048 { return Err("Invalid login request".into()); }
        line.push(byte);
    }
    #[derive(serde::Deserialize)] struct Login { mnemonic: String }
    let login: Login = serde_json::from_slice(&line).map_err(|_| "Invalid login request")?;
    Ok(Zeroizing::new(login.mnemonic))
}
async fn run() -> Result<(), Failure> {
    let args: Vec<_> = std::env::args().collect();
    if args.get(1).map(String::as_str) == Some("--version") {
        println!("xmr-nym-client 0.2.0 (authenticated; NymVPN 2026.13.0)"); return Ok(());
    }
    if args.len() != 5 || args[1] != "--authenticated" {
        return Err("Authenticated mode requires an address, previous exit and private data directory".into());
    }
    let bind: SocketAddr = args[2].parse()?;
    if bind.ip() != std::net::Ipv4Addr::LOCALHOST || bind.port() == 0 {
        return Err("Only a nonzero loopback port is supported".into());
    }
    let previous_exit = &args[3];
    let root = Path::new(&args[4]);
    if !root.is_absolute() { return Err("An absolute private data directory is required".into()); }
    let phrase = tokio::time::timeout(Duration::from_secs(15), read_phrase()).await??;
    account::parse_phrase(&phrase)?; // no network, storage or listener before validation
    drop(std::net::TcpListener::bind(bind)?);
    let connect = async {
        event(json!({"event":"authenticating"}));
        let access = account::authenticate(&phrase, root).await?;
        let details: nym_sdk::NymNetworkDetails = access.network.nym_network_details().clone().into();
        let urls = details.nym_api_urls();
        let mut providers = Vec::new();
        for url in urls {
            let api = nym_http_api_client::Client::new_url(url.url, Some(Duration::from_secs(30)))?;
            if let Ok(nodes) = api.get_all_described_nodes_v2().await {
                providers = nodes.into_iter().filter_map(|node| node.description.network_requester)
                    .map(|nr| nr.address).filter(|address| address.split('@').next_back().unwrap_or("") != previous_exit)
                    .collect();
                if !providers.is_empty() { break; }
            }
        }
        let provider = providers.choose(&mut rand::rng()).ok_or("No alternative Nym exit is available")?.clone();
        let mut config = Socks5::new(provider.clone()); config.bind_address = bind;
        let client = MixnetClientBuilder::new_ephemeral()
            .network_details(details).enable_credentials_mode()
            .with_custom_bandwidth_provider(Box::new(access.bandwidth.clone()))
            .socks5_config(config).build()?.connect_to_mixnet_via_socks5().await?;
        tokio::time::timeout(Duration::from_secs(10), async {
            loop {
                if let Ok(mut socket) = tokio::net::TcpStream::connect(bind).await {
                    socket.write_all(&[5, 1, 0]).await?;
                    let mut reply = [0; 2]; socket.read_exact(&mut reply).await?;
                    if reply != [5, 0] { return Err(io::Error::other("Invalid SOCKS5 listener")); }
                    return Ok::<(), io::Error>(());
                }
                tokio::time::sleep(Duration::from_millis(50)).await;
            }
        }).await??;
        Ok::<_, Failure>((client, provider, access))
    };
    let (client, provider, access) = tokio::select! {
        result = tokio::time::timeout(Duration::from_secs(240), connect) => result??,
        _ = stop_requested() => return Ok(()),
    };
    drop(phrase);
    event(json!({"event":"ready", "authenticated":true, "address":bind.to_string(), "device":access.device,
        "entry":client.nym_address().to_string().split('@').next_back().unwrap_or(""),
        "exit":provider.split('@').next_back().unwrap_or("")}));
    stop_requested().await;
    // Avoid SDK shutdown races; exiting closes every socket in our own process.
    std::process::exit(0);
}
#[tokio::main]
async fn main() {
    #[cfg(unix)] unsafe { libc::umask(0o077); }
    tracing_subscriber::fmt().with_writer(io::stderr).with_ansi(false).with_env_filter("error").init();
    let code = match run().await { Ok(()) => 0, Err(error) => {
        event(json!({"event":"error", "message":error.to_string()})); 1
    }};
    std::process::exit(code);
}
