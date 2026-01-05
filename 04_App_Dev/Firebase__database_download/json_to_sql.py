import sqlite3
import json
import os

# 1. 設定路徑 (保持您的自定義路徑)
BASE_PATH = r'D:\product_recognition\04_App_Dev\Firebase__database_download'
PRODUCTS_JSON = os.path.join(BASE_PATH, 'products.json')
SALES_JSON = os.path.join(BASE_PATH, 'sales.json')
DB_FILE = os.path.join(BASE_PATH, "grocery_system.db")

def init_sql_database():
    # 建立或連接到資料庫檔
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # --- A. 建立產品資料表 ---
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            name TEXT,
            price REAL,
            class TEXT,       -- 對應 JSON 中的 category
            stock INTEGER,
            last_update TEXT  -- 對應 JSON 中的 lastUpdate
        )
    ''')

    # --- B. 建立銷售紀錄資料表 ---
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sales (
            id TEXT PRIMARY KEY,
            total_amount REAL,
            timestamp TEXT,
            items TEXT -- 存儲為 JSON 字串
        )
    ''')

    # 2. 匯入產品資料 (修正欄位對應)
    if os.path.exists(PRODUCTS_JSON):
        with open(PRODUCTS_JSON, 'r', encoding='utf-8') as f:
            products = json.load(f)
            for p in products:
                # 🚩 修正重點：使用 p.get('category') 填入 class 欄位
                # 🚩 修正重點：使用 p.get('lastUpdate') 填入 last_update 欄位
                cursor.execute('''
                    INSERT OR REPLACE INTO products (id, name, price, class, stock, last_update)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (
                    p.get('id'), 
                    p.get('name'), 
                    p.get('price'), 
                    p.get('category'), # 這裡改拿 category
                    p.get('stock', 0), 
                    p.get('lastUpdate') # 這裡改拿 lastUpdate
                ))
        print(f"✅ 產品資料已匯入 SQL ({len(products)} 筆)，已修正 class 與 last_update 欄位。")

    # 3. 匯入銷售資料 (保持不變)
    if os.path.exists(SALES_JSON):
        with open(SALES_JSON, 'r', encoding='utf-8') as f:
            sales = json.load(f)
            for s in sales:
                items_str = json.dumps(s.get('items', []), ensure_ascii=False)
                cursor.execute('''
                    INSERT OR REPLACE INTO sales (id, total_amount, timestamp, items)
                    VALUES (?, ?, ?, ?)
                ''', (s.get('id'), s.get('total_amount'), s.get('timestamp'), items_str))
        print(f"✅ 銷售紀錄已匯入 SQL ({len(sales)} 筆)")

    conn.commit()
    conn.close()
    print(f"✨ 本地 SQL 資料庫已重新生成：{DB_FILE}")

if __name__ == "__main__":
    init_sql_database()