import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
from datetime import datetime
from dotenv import load_dotenv # 引入 dotenv


# 載入環境變數
load_dotenv()


# 🚩 演習重點：從環境變數讀取金鑰路徑與基礎路徑
FIREBASE_KEY = os.getenv('FIREBASE_KEY_PATH')
BASE_PATH = os.getenv('BASE_SAVE_PATH', r'D:\product_recognition\04_App_Dev')


# 1. 初始化 Firebase 連線
if not firebase_admin._apps:
    if FIREBASE_KEY and os.path.exists(FIREBASE_KEY):
        # 🚩 修正：使用環境變數變數，而非硬編碼字串
        cred = credentials.Certificate(FIREBASE_KEY)
        firebase_admin.initialize_app(cred)
    else:
        print("❌ 錯誤：找不到 Firebase 金鑰，請檢查 .env 設定")
        exit()

db = firestore.client()

# 定義儲存路徑
PRODUCTS_OUT = os.path.join(BASE_PATH, 'products.json')
SALES_OUT = os.path.join(BASE_PATH, 'sales.json')

def json_serializable(item):
    """處理 Firebase 回傳資料中無法直接轉 JSON 的型態"""
    for key, value in item.items():
        # 處理時間格式 (解決 DatetimeWithNanoseconds 錯誤)
        if hasattr(value, 'isoformat'):
            item[key] = value.isoformat()
        # 如果銷售紀錄中有巢狀字典，也遞迴處理
        elif isinstance(value, dict):
            json_serializable(value)
    return item

def pull_collection(collection_name, output_file):
    print(f"🚀 正在從 Firebase 抓取 [{collection_name}] 集合...")
    
    docs = db.collection(collection_name).stream()
    data_list = []
    
    for doc in docs:
        item = doc.to_dict()
        item['id'] = doc.id # 保留文件 ID
        # 處理時間物件轉換
        data_list.append(json_serializable(item))
    
    if not data_list:
        print(f"⚠️ 雲端 [{collection_name}] 是空的。")
        return

    # 確保資料夾存在
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data_list, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 成功！[{collection_name}] 已存至: {output_file}")

if __name__ == "__main__":
    # 同時抓取兩個集合
    pull_collection('products', PRODUCTS_OUT)
    pull_collection('sales', SALES_OUT)