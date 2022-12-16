# Script to identify node locations and service providers

import requests
import socket
import threading
import os
import IP2Location

# todo
# 1. Write a spider algo to branch out from starting_node
#    and query locations for all other peered nodes in the network
# 2. Support http and https queries
# 3. Pipe data to google maps api
# 4. Identify host providers, print list in order of occurrence

# Set this to an authentic node in the network
starting_node = "https://node.zenon.fun:35997"

def getHostInfo(ip):
    database = IP2Location.IP2Location(os.path.join("data", "IP2LOCATION-LITE-DB3.BIN"))

    try:
        host = socket.gethostbyaddr(ip)
        rec = database.get_all(ip)
        country = rec.country_long
        region = rec.region
        city = rec.city
        print(host, " || " + city + ", " + region + ", " + country)
    except:
        print(ip, "could not be reached")


if __name__ == '__main__':
    p = {"jsonrpc": "2.0", "id": 40, "method": "stats.networkInfo", "params": []}
    h = {"content-type": "application/json"}
    x = requests.get(starting_node, headers=h, json=p)

    data = x.json()
    peers = data['result']['peers']

    for peer in peers:
        ip = peer['ip']
        threads = []
        try:
            t = threading.Thread(target=getHostInfo, args=(ip,))
            threads.append(t)
        except:
            print ("Error: unable to start thread")

        for t in threads:
            t.start()

        for t in threads:
            t.join()
