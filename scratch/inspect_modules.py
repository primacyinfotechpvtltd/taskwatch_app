import xmlrpc.client

url = 'http://192.168.1.22:8097'
db = 'wfh160726'
username = 'admin'
password = '1234'

try:
    common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
    uid = common.authenticate(db, username, password, {})
    models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')
    
    modules = models.execute_kw(db, uid, password, 'ir.module.module', 'search_read', [[['state', '=', 'installed']]], {
        'fields': ['name', 'shortdesc', 'summary']
    })
    
    print("--- Installed Custom Modules ---")
    for m in modules:
        if 'task' in m['name'].lower() or 'wfh' in m['name'].lower() or 'api' in m['name'].lower() or 'pi' in m['name'].lower():
            print(f"Name: {m['name']}, Desc: {m['shortdesc']}")
            
except Exception as e:
    print(f"Error: {e}")
