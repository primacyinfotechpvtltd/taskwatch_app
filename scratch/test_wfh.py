import xmlrpc.client

url = 'http://192.168.1.22:8097'
db = 'wfh160726'
username = 'admin'
password = '1234'

try:
    print(f"Connecting to {url}...")
    common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
    uid = common.authenticate(db, username, password, {})
    print(f"Authenticated successfully, uid: {uid}")
    
    models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')
    
    # Query hr.employee records
    employees = models.execute_kw(db, uid, password, 'hr.employee', 'search_read', [[]], {
        'fields': ['id', 'name', 'work_location_type', 'user_id', 'work_email']
    })
    
    print("\n--- Employees ---")
    for emp in employees:
        print(f"ID: {emp['id']}, Name: {emp['name']}, Email: {emp['work_email']}, Location Type: {emp.get('work_location_type')}, User ID: {emp.get('user_id')}")

    # Query pi.wfh.request records
    requests = models.execute_kw(db, uid, password, 'pi.wfh.request', 'search_read', [[]], {
        'fields': ['id', 'employee_id', 'date_from', 'date_to', 'state']
    })
    
    print("\n--- WFH Requests ---")
    for req in requests:
        print(f"ID: {req['id']}, Employee: {req['employee_id']}, From: {req['date_from']}, To: {req['date_to']}, State: {req['state']}")

except Exception as e:
    print(f"Error: {e}")
