import xmlrpc.client

url = 'http://192.168.1.22:8097'
db = 'wfh160726'
username = 'admin'
password = '1234'

try:
    common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
    uid = common.authenticate(db, username, password, {})
    models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')
    
    # Read Aka Foster's employee record (ID 22)
    aka_data = models.execute_kw(db, uid, password, 'hr.employee', 'read', [[22]], {
        'fields': [
            'id', 'name', 'work_location_id', 'work_location_name', 'work_location_type', 
            'today_location_name', 'monday_location_id', 'tuesday_location_id',
            'wednesday_location_id', 'thursday_location_id', 'friday_location_id',
            'saturday_location_id', 'sunday_location_id'
        ]
    })
    
    print("--- Aka Foster Employee Record ---")
    for k, v in aka_data[0].items():
        print(f"{k}: {v}")
        
    # Let's read work locations
    loc_ids = []
    for k, v in aka_data[0].items():
        if 'location_id' in k and isinstance(v, list):
            loc_ids.append(v[0])
    if aka_data[0]['work_location_id']:
        loc_ids.append(aka_data[0]['work_location_id'][0])
        
    if loc_ids:
        locations = models.execute_kw(db, uid, password, 'hr.work.location', 'read', [list(set(loc_ids))], {
            'fields': ['id', 'name', 'location_type']
        })
        print("\n--- Work Locations ---")
        for loc in locations:
            print(loc)
            
except Exception as e:
    print(f"Error: {e}")
