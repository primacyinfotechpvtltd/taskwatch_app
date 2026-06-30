import requests
import json

url = "https://app.primacyinfotech.com"
session_id = "wtfxM8G4M0Wehc38jqDbgwaL4qYJgX8Ai0A0aOWAjSa2urTXBvAf6mCJxmNowocoWlUZ9xy8Qv0ShleC-ytc"

headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    'Cookie': f'session={session_id}; session_id={session_id}'
}

def test_call(model, method, args, kwargs):
    endpoint = f"{url}/web/dataset/call_kw/{model}/{method}"
    payload = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
            "model": model,
            "method": method,
            "args": args,
            "kwargs": kwargs
        },
        "id": 1
    }
    
    print(f"\nCalling {model}.{method} via {endpoint}...")
    try:
        res = requests.post(endpoint, headers=headers, json=payload, timeout=10)
        print("Status code:", res.statusCode if hasattr(res, 'statusCode') else res.status_code)
        try:
            print("Response:", json.dumps(res.json(), indent=2))
        except Exception:
            print("Raw response:", res.text)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    # Test discuss.channel search_read
    test_call(
        "discuss.channel", 
        "search_read", 
        [[]], 
        {
            "fields": ["id", "name", "channel_type", "description", "channel_partner_ids"],
            "order": "write_date desc"
        }
    )
