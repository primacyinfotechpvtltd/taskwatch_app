import xmlrpc.client

url = 'http://192.168.1.22:8097'
db = 'wfh160726'
username = 'admin'
password = '1234'

try:
    common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
    uid = common.authenticate(db, username, password, {})
    models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')
    
    email = 'abcakad@gmail.com'
    userId = 9 # Aka Foster user_id is 9
    
    # Check domain 1
    domain1 = [
        '|',
        ['work_email', '=', email],
        ['user_id.login', '=', email],
    ]
    res1 = models.execute_kw(db, uid, password, 'hr.employee', 'search_read', [domain1], {
        'fields': ['id', 'name', 'work_email']
    })
    print("Domain 1 result:", res1)
    
    # Check domain 2
    domain2 = [
        ['user_id', '=', userId]
    ]
    res2 = models.execute_kw(db, uid, password, 'hr.employee', 'search_read', [domain2], {
        'fields': ['id', 'name']
    })
    print("Domain 2 result:", res2)
    
    # Check res.users
    res_user = models.execute_kw(db, uid, password, 'res.users', 'read', [[userId]], {
        'fields': ['login', 'employee_id']
    })
    print("Res User result:", res_user)
    
except Exception as e:
    print("Error:", e)
