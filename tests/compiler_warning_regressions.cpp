// Regression checks for ownership and certificate generation changes.
// Run with tests/run_compiler_warning_regressions.sh after building epee.
#include <algorithm>
#include <cassert>
#include <cstdint>
#include <deque>
#include <iostream>
#include <vector>
#include <utility>
#include <openssl/evp.h>
#include <openssl/x509.h>
#include <openssl/core_names.h>
#include "rolling_median.h"
#include "rapidjson/document.h"

namespace epee { namespace net_utils {
bool create_rsa_ssl_certificate(EVP_PKEY*&, X509*&);
bool create_ec_ssl_certificate(EVP_PKEY*&, X509*&, int);
}}

static void median_moves()
{
    using Median = epee::misc_utils::rolling_median_t<uint64_t>;
    Median median(31);
    std::deque<uint64_t> history;
    for (uint64_t i = 0; i < 1000; ++i) {
        const auto value = (i * 7919) % 1009;
        median.insert(value);
        history.push_back(value);
        if (history.size() > 31) history.pop_front();
        std::vector<uint64_t> sorted(history.begin(), history.end());
        std::sort(sorted.begin(), sorted.end());
        const auto expected = (sorted[(sorted.size()-1)/2] + sorted[sorted.size()/2])/2;
        assert(median.median() == expected);
        Median moved(std::move(median));
        assert(moved.median() == expected);
        median = std::move(moved);
        auto* alias = &median;
        median = std::move(*alias);
        assert(median.median() == expected);
    }
    Median survivor(2);
    {
        Median source(3);
        source.insert(10); source.insert(20); source.insert(30);
        survivor = std::move(source);
    }
    assert(survivor.median() == 20);
    survivor.insert(40);
    assert(survivor.median() == 30);
}

static void json_ownership()
{
    // CrtAllocator frees each allocation, detecting double frees/leaks that a pool masks.
    using Doc = rapidjson::GenericDocument<rapidjson::UTF8<>, rapidjson::CrtAllocator>;
    for (unsigned i = 0; i < 1000; ++i) {
        Doc doc;
        doc.Parse(R"({"a":[{"long_name_to_force_heap_storage":"long_value_to_force_heap_storage"},[1,2,3]],"empty":{},"array":[]})");
        assert(!doc.HasParseError());
        assert(doc["a"][0]["long_name_to_force_heap_storage"] == "long_value_to_force_heap_storage");
        assert(doc["a"][1][2].GetInt() == 3);
        Doc moved(std::move(doc));
        assert(moved["empty"].IsObject());
        moved["a"].PopBack();
        assert(moved["a"].Size() == 1);
        moved.RemoveMember("a");
        moved.Parse("[null,true,{},[],\"another_heap_allocated_string_value\"]");
        assert(!moved.HasParseError());
    }
}

static void certificates()
{
    for (const bool rsa : {false, true}) {
        EVP_PKEY* key = nullptr;
        X509* cert = nullptr;
        const bool ok = rsa ? epee::net_utils::create_rsa_ssl_certificate(key, cert)
            : epee::net_utils::create_ec_ssl_certificate(key, cert, NID_secp256k1);
        assert(ok && key && cert);
        assert(X509_verify(cert, key) == 1);
        assert(X509_check_private_key(cert, key) == 1);
        assert(EVP_PKEY_bits(key) == (rsa ? 4096 : 256));
        assert(X509_cmp_current_time(X509_get0_notAfter(cert)) > 0);
        EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new(key, nullptr);
        assert(ctx && EVP_PKEY_check(ctx) == 1);
        EVP_PKEY_CTX_free(ctx);
        if (rsa) {
            BIGNUM* exponent = nullptr;
            assert(EVP_PKEY_get_bn_param(key, OSSL_PKEY_PARAM_RSA_E, &exponent) == 1);
            assert(BN_get_word(exponent) == 65537);
            BN_free(exponent);
        }
        X509_free(cert); EVP_PKEY_free(key);
    }
    EVP_PKEY* key = nullptr;
    X509* cert = nullptr;
    assert(!epee::net_utils::create_ec_ssl_certificate(key, cert, NID_undef));
    assert(!key && !cert);
}
int main()
{
    median_moves(); json_ownership(); certificates();
    std::cout << "Median moves, JSON ownership and TLS certificates: PASS\n";
}
