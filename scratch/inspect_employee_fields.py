import xmlrpc.client

url = 'http://192.168.1.22:8097'
db = 'wfh160726'
username = 'admin'
password = '1234'

try:
    common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
    uid = common.authenticate(db, username, password, {})
    models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')
    
    fields = models.execute_kw(db, uid, password, 'hr.employee', 'fields_get', [], {
        'attributes': ['string', 'type', 'selection']
    })
    
    print("--- Fields containing 'wfh' or 'home' or 'location' ---")
    for name, info in fields.items():
        if any(x in name.lower() or x in info.get('string', '').lower() for x in ['wfh', 'home', 'location']):
            print(f"Field: {name}")
            print(f"  String: {info.get('string')}")
            print(f"  Type: {info.get('type')}")
            if 'selection' in info:
                print(f"  Selection: {info.get('selection')}")
            print()
            
except Exception as e:
    print(f"Error: {e}")
