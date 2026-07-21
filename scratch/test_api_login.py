import requests

url = 'http://192.168.1.22:8097/api/login'
payload = {
    'db': 'wfh160726',
    'login': 'abcakad@gmail.com',
    'password': '123'  # Let's see what password Aka Foster uses. Or maybe we can log in with admin.
}

# Wait, let's also try admin/1234
payload_admin = {
    'db': 'wfh160726',
    'login': 'admin',
    'password': '1234'
}

try:
    print("Trying admin login...")
    r = requests.post(url, json=payload_admin)
    print("Status code:", r.status_code)
    print("Response json:", r.json())
    
    # Let's see if we can find the password for Aka Foster from Odoo db
    # We can use xmlrpc to query res.users to see if there is password or if we can change it / read it.
    
except Exception as e:
    print("Error:", e)
