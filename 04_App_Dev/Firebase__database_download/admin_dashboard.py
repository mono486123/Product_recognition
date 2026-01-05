
#請使用streamlit run "D:\product_recognition\04_App_Dev\admin_dashboard.py"

import streamlit as st
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# 1. 初始化 Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

st.set_page_config(page_title="雜貨店雲端後台", layout="wide")
st.title("🏬 雜貨店管理員後台") 

# --- 側邊欄：功能導航 ---
menu = st.sidebar.selectbox("功能選單", ["庫存管理", "銷售統計", "AI 辨識分析"])

# --- 功能 1：庫存管理 ---
if menu == "庫存管理":
    st.header("📦 即時庫存監控")
    
    # 從 Firebase 抓取資料
    products_ref = db.collection('products')
    docs = products_ref.stream()
    
    items = []
    for doc in docs:
        d = doc.to_dict()
        d['id'] = doc.id
        items.append(d)
    
    df = pd.DataFrame(items)
    
    # 顯示編輯表格
    if not df.empty:
        # 低庫存預警
        low_stock = df[df['stock'] < 10]
        if not low_stock.empty:
            st.warning(f"注意！有 {len(low_stock)} 項商品庫存不足！")
        
        st.data_editor(df, key="inventory_editor", use_container_width=True)
        
        if st.button("更新雲端資料"):
            # 這裡可以寫回傳邏輯
            st.success("已同步更新至手機端！")

# --- 功能 2：銷售統計 ---
elif menu == "銷售統計":
    st.header("💰 每日消額與淨利分析")
    
    sales_ref = db.collection('sales').order_by('timestamp', direction='DESCENDING')
    sales_docs = sales_ref.stream()
    
    sales_data = []
    for doc in sales_docs:
        s = doc.to_dict()
        # 處理時間格式
        s['time'] = s['timestamp'].strftime('%Y-%m-%d %H:%M') if s.get('timestamp') else "N/A"
        sales_data.append(s)
    
    if sales_data:
        sdf = pd.DataFrame(sales_data)
        
        col1, col2 = st.columns(2)
        with col1:
            st.metric("今日總營業額", f"$ {sdf['total_amount'].sum()}")
        with col2:
            st.metric("交易筆數", len(sdf))
            
        st.subheader("最近交易紀錄")
        st.table(sdf[['time', 'total_amount', 'items']])
    else:
        st.info("目前尚無銷售資料。")