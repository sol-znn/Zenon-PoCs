# Script to identify active node locations and service providers

import IP2Location
import os
import requests
import socket
import threading
import urllib3

checked = []    # ip added to this array if we've attempted to pull its stats.networkInfo
responded = []  # ip added to this array if it responds with data for stats.networkInfo
nodes = []      # temp array of nodes
locations = []  # for each ip in responded[], query for its location and host provider details
providers = {}  # occurrence of domain names for each node's service provider


# Get IP location for a live node
def getHostInfo(ip):
    database = IP2Location.IP2Location(os.path.join("data", "IP2LOCATION-LITE-DB3.BIN"))
    rec = database.get_all(ip)
    try:
        host = socket.gethostbyaddr(ip)
        host = host[0]
    except:
        host = "no-host-info"
        pass

    try:
        _p = host.split(".")[-2] + "." + host.split(".")[-1]
    except:
        _p = host

    if (_p in providers.keys()):
        providers[_p] += 1
    else:
        providers[_p] = 1
    locations.append("{}: {} || {}, {}, {}".format(ip, host, rec.city, rec.region, rec.country_long))


# Get network details for individual IPs
def getPeers(ip):
    global results
    params = {"jsonrpc": "2.0", "id": 40, "method": "stats.networkInfo", "params": []}
    header = {"content-type": "application/json"}
    ip = ip.strip()
    checked.append(ip)

    try:
        results = requests.get("http://" + ip + ":35997", headers=header, json=params, timeout=20)
    except Exception as e:
        # print(e)
        pass

    if "HTTPS" in results.content.__str__():
        try:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
            results = requests.get("https://" + ip + ":35997", headers=header, json=params, timeout=20, verify=False)
        except:
            pass

    if results.status_code == 200:
        responded.append(ip)
        data = results.json()
        peers = data['result']['peers']
        for peer in peers:
            nodes.append(peer['ip'])


# Thread Handler
def dispatcher(ipList, func):
    global t
    threads = []

    for ip in ipList:
        if func == "getPeers":
            t = threading.Thread(target=getPeers, args=(ip,))
        elif func == "getHostInfo":
            t = threading.Thread(target=getHostInfo, args=(ip,))
        threads.append(t)

    for t in threads:
        t.start()

    for t in threads:
        t.join()


# De-duplicates a list of IPs
def dedupeList(nodes):
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
    seeders = open('seeders.txt', 'r')
    lines = seeders.readlines()
    dispatcher(lines, "getPeers")
    nodes = dedupeList(nodes)
    print("Done!")

    # Spider to find all other nodes
    print("[!] Getting remaining node data...", end=" ")
    checkedAll = False
    while not checkedAll:
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
            checkedAll = True
        else:
            dispatcher(_nodes, "getPeers")
            nodes = dedupeList(nodes)
            responded = dedupeList(responded)
            checked = dedupeList(checked)
    print("Done!")

    print("[!] Getting node location data...", end=" ")
    dispatcher(responded, "getHostInfo")
    print("Done!")
    print("----------")
    print("Checked ({}): {}".format(len(checked), checked))
    print("Responded ({}): {}".format(len(responded), responded))
    print("Providers ({}): {}".format(len(providers), providers))
    print("----------")

    for n in locations:
        print(n)
