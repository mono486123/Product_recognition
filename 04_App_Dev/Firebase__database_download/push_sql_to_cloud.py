import sqlite3
import firebase_admin
from firebase_admin import credentials, firestore
import os
from dotenv import load_dotenv

# 1. 載入環境變數
load_dotenv()


# 🚩 演習重點：從環境變數讀取金鑰路徑與資料庫路徑
SERVICE_ACCOUNT_PATH = os.getenv('FIREBASE_KEY_PATH', r"D:\product_recognition\04_App_Dev\serviceAccountKey.json")
DB_FILE = os.getenv('DB_PATH', r'D:\product_recognition\04_App_Dev\Firebase__database_download\grocery_system.db')


# 2. 初始化 Firebase
if not firebase_admin._apps:
    if SERVICE_ACCOUNT_PATH and os.path.exists(SERVICE_ACCOUNT_PATH):
        # 🚩 修正：確保使用變數而非硬編碼字串
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    else:
        print(f"❌ 錯誤：找不到金鑰檔案 {SERVICE_ACCOUNT_PATH}")
        exit()

        
db = firestore.client()

def push_sql_to_cloud():
    if not os.path.exists(DB_FILE):
        print(f"❌ 錯誤：找不到資料庫檔案 {DB_FILE}")
        return

    # 連結本地 SQL
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    try:
        # 讀取本地所有的產品資料
        print("🔍 正在讀取本地 SQL 資料...")
        cursor.execute("SELECT id, name, price, class, stock, last_update FROM products")
        rows = cursor.fetchall()
        
        if not rows:
            print("⚠️ SQL 資料庫中沒有產品資料。")
            return

        print(f"🚀 開始同步 {len(rows)} 筆資料至 Firebase...")
        
        for row in rows:
            p_id, name, price, p_class, stock, last_update = row
            
            # 準備上傳的資料字典
            # 這裡將 SQL 的 'class' 對應回 Firebase 的 'category'
            # 將 SQL 的 'last_update' 對應回 Firebase 的 'lastUpdate'
            doc_data = {
                'id': p_id,
                'name': name,
                'price': price,
                'category': p_class,
                'stock': stock,
                'lastUpdate': last_update
            }
            
            # 執行同步：使用 set(merge=True) 以免覆蓋掉雲端其他可能存在的自定義欄位
            db.collection('products').document(p_id).set(doc_data, merge=True)
            print(f"✅ 同步成功：{name} ({p_id})")
            
        print("\n✨ 所有本地更動已成功推播至雲端 Firebase！")

    except Exception as e:
        print(f"❌ 同步過程中發生錯誤：{e}")
    finally:
        conn.close()

if __name__ == "__main__":
    push_sql_to_cloud()