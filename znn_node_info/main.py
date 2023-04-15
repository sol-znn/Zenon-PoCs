# Script to identify active node locations and service providers

from cymruwhois import Client
import IP2Location
import json
import os
import requests
import socket
import threading

verbose = False
checked = []  # ip added to this array if we've attempted to pull its stats.networkInfo
responded = []  # ip added to this array if it responds with data for stats.networkInfo
nodes = []  # temp array of nodes
locations = []  # for each ip in responded[], query for its location and host provider details
providers = {}  # occurrence of domain names for each node's service provider
output_nodes = os.path.join("data", "output_nodes.json")
output_providers = os.path.join("data", "output_providers.json")


# Get IP location for a live node
def get_host_info(ip):
    database = IP2Location.IP2Location(os.path.join("data", "IP2LOCATION-LITE-DB3.BIN"))
    rec = database.get_all(ip)
    c = Client()
    try:
        host = socket.gethostbyaddr(ip)
        host = host[0]
        _p = host.split(".")[-2] + "." + host.split(".")[-1]
    except:
        try:
            r = c.lookup(ip)
            _p = r.owner
            if verbose:
                print("{}: {}".format(ip, _p))
        except:
            _p = "no-host-info"

    if _p in providers.keys():
        providers[_p] += 1
    else:
        providers[_p] = 1

    try:
        params = {"jsonrpc": "2.0", "id": 40, "method": "stats.processInfo", "params": []}
        results, connection, domain = send_request(ip, params)
        data = results.json()
        znnd_version = data['result']['version']
    except:
        znnd_version, domain = None, None
        print("could not retrieve processInfo for {}".format(ip))

    if domain is not None:
        _json = {
            "ip": ip,
            "domain": "https://{}".format(domain),
            "znnd": znnd_version,
            "provider": _p,
            "city": rec.city,
            "region": rec.region,
            "country": rec.country_long
        }
    else:
        _json = {
            "ip": ip,
            "znnd": znnd_version,
            "provider": _p,
            "city": rec.city,
            "region": rec.region,
            "country": rec.country_long
        }
    locations.append(_json)
    # locations.append("{}: {} || {}, {}, {}".format(ip, _p, rec.city, rec.region, rec.country_long))


# Get network details for individual IPs
# Attempt https first
# If that fails due to CertificateError, extract domain from error and try again
# Attempt http as a last resort
def get_peers(ip):
    params = {"jsonrpc": "2.0", "id": 40, "method": "stats.networkInfo", "params": []}
    ip = ip.strip()
    checked.append(ip)

    results, connection, domain = send_request(ip, params)

    if results is not None and connection is not None and results.status_code == 200:
        if verbose:
            if domain is not None:
                print("{} ({}): {}".format(domain, connection, results.json()))
            else:
                print("{} ({}): {}".format(ip, connection, results.json()))
        responded.append(ip)
        data = results.json()
        peers = data['result']['peers']
        for peer in peers:
            nodes.append(peer['ip'])


def send_request(ip, params):
    header = {"content-type": "application/json"}
    results, connection, domain = None, None, None
    try:
        results = requests.get("https://" + ip + ":35997", headers=header, json=params, timeout=10)
    except requests.exceptions.SSLError as ce:
        if "CertificateError" in ce.__str__():
            try:
                domain = ce.__str__().split("'")[-2]  # there is probably a better way to access this data
                results = requests.get("https://" + domain + ":35997", headers=header, json=params, timeout=10)
                connection = "https"
            except Exception as d:
                if verbose:
                    print("domain query failed: ({}): {}".format(domain, d))
                pass
        else:
            try:
                results = requests.get("http://" + ip + ":35997", headers=header, json=params, timeout=10)
                connection = "http"
            except:
                pass
    except:
        try:
            results = requests.get("http://" + ip + ":35997", headers=header, json=params, timeout=10)
            connection = "http"
        except:
            pass

    return results, connection, domain


# Thread Handler
def dispatcher(ip_list, func):
    t = None
    threads = []

    for ip in ip_list:
        if func == "getPeers":
            t = threading.Thread(target=get_peers, args=(ip,))
        elif func == "getHostInfo":
            t = threading.Thread(target=get_host_info, args=(ip,))
        threads.append(t)

    for t in threads:
        t.start()

    for t in threads:
        t.join()


# De-duplicates a list of IPs
def dedupe_list(nodes):
    _nodes = []
    while len(nodes) > 0:
        _n = nodes.pop(0)
        discovered = False
        for n in nodes:
            if _n == n:
                discovered = True
                break
        if not discovered:
            _nodes.append(_n)
    return _nodes


if __name__ == '__main__':
    # Start with seeders,txt
    print("[!] Getting Seeder node data...", end=" ")
    seeders = open(os.path.join("data", "seeders.txt"), 'r')
    lines = seeders.readlines()
    dispatcher(lines, "getPeers")
    nodes = dedupe_list(nodes)
    print("Done!")

    # Spider to find all other nodes
    print("[!] Getting remaining node data...", end=" ")
    checked_all = False
    while not checked_all:
        _nodes = []  # nodes to be checked
        for n in nodes:
            alreadyChecked = False
            for c in checked:
                if c == n:
                    alreadyChecked = True
                    break
            if not alreadyChecked:
                _nodes.append(n)
        if len(_nodes) == 0:
            checked_all = True
        else:
            dispatcher(_nodes, "getPeers")
            nodes = dedupe_list(nodes)
            responded = dedupe_list(responded)
            checked = dedupe_list(checked)
    print("Done!")

    print("[!] Getting node location data...", end=" ")
    dispatcher(responded, "getHostInfo")
    print("Done!")

    print("[!] Saving data to files...", end=" ")
    with open(output_providers, "w") as outfile:
        json.dump(providers, outfile, indent=4)

    with open(output_nodes, "w") as outfile:
        json.dump(locations, outfile, indent=4)
    print("Done!")

    if verbose:
        print("----------")
        print("Checked ({}): {}".format(len(checked), checked))
        print("Responded ({}): {}".format(len(responded), responded))
        print("Providers ({}): {}".format(len(providers), providers))
        print("----------")
        for n in locations:
            print(n)
