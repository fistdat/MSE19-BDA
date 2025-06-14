-- =============================================
-- TRINO ANALYTICS QUERIES FOR CDC DATA LAKEHOUSE
-- =============================================

-- 1. BASIC DATA EXPLORATION
-- ========================================

-- Count total records in each table
SELECT 'users' as table_name, COUNT(*) as record_count 
FROM iceberg.raw_data.users
UNION ALL
SELECT 'accounts' as table_name, COUNT(*) as record_count 
FROM iceberg.raw_data.accounts;

-- Check data freshness (recent CDC events)
SELECT 
    source_table,
    op as operation_type,
    COUNT(*) as event_count,
    MAX(from_unixtime(ts_ms/1000)) as latest_event_time
FROM iceberg.raw_data.users 
GROUP BY source_table, op
ORDER BY latest_event_time DESC;

-- 2. PARSED USER DATA ANALYTICS
-- ========================================

-- Extract and parse user data from JSON
WITH parsed_users AS (
    SELECT 
        json_extract_scalar(data, '$.id') as user_id,
        json_extract_scalar(data, '$.email') as email,
        json_extract_scalar(data, '$.name') as name,
        json_extract_scalar(data, '$.created_at') as created_at,
        op as operation_type,
        from_unixtime(ts_ms/1000) as event_timestamp
    FROM iceberg.raw_data.users 
    WHERE op IN ('c', 'u') -- Only CREATE and UPDATE operations
)
SELECT 
    user_id,
    email,
    name,
    operation_type,
    event_timestamp,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp DESC) as rn
FROM parsed_users
ORDER BY event_timestamp DESC;

-- 3. PARSED ACCOUNT DATA ANALYTICS  
-- ========================================

-- Extract and parse account data from JSON
WITH parsed_accounts AS (
    SELECT 
        json_extract_scalar(data, '$.id') as account_id,
        json_extract_scalar(data, '$.user_id') as user_id,
        json_extract_scalar(data, '$.currency') as currency,
        CAST(json_extract_scalar(data, '$.balance') as DECIMAL(10,2)) as balance,
        op as operation_type,
        from_unixtime(ts_ms/1000) as event_timestamp
    FROM iceberg.raw_data.accounts 
    WHERE op IN ('c', 'u') -- Only CREATE and UPDATE operations
)
SELECT 
    account_id,
    user_id,
    currency,
    balance,
    operation_type,
    event_timestamp
FROM parsed_accounts
ORDER BY event_timestamp DESC;

-- 4. COMBINED USER & ACCOUNT ANALYTICS
-- ========================================

-- Join users and accounts for comprehensive view
WITH latest_users AS (
    SELECT 
        json_extract_scalar(data, '$.id') as user_id,
        json_extract_scalar(data, '$.email') as email,
        json_extract_scalar(data, '$.name') as name,
        ROW_NUMBER() OVER (PARTITION BY json_extract_scalar(data, '$.id') ORDER BY ts_ms DESC) as rn
    FROM iceberg.raw_data.users 
    WHERE op IN ('c', 'u')
),
latest_accounts AS (
    SELECT 
        json_extract_scalar(data, '$.user_id') as user_id,
        json_extract_scalar(data, '$.currency') as currency,
        CAST(json_extract_scalar(data, '$.balance') as DECIMAL(10,2)) as balance,
        ROW_NUMBER() OVER (PARTITION BY json_extract_scalar(data, '$.user_id') ORDER BY ts_ms DESC) as rn
    FROM iceberg.raw_data.accounts 
    WHERE op IN ('c', 'u')
)
SELECT 
    u.email,
    u.name,
    a.currency,
    a.balance,
    CASE 
        WHEN a.balance >= 10000 THEN 'Premium+'
        WHEN a.balance >= 5000 THEN 'Premium'
        WHEN a.balance >= 1000 THEN 'Standard'
        ELSE 'Basic'
    END as account_tier
FROM latest_users u
LEFT JOIN latest_accounts a ON u.user_id = a.user_id
WHERE u.rn = 1 AND (a.rn = 1 OR a.rn IS NULL)
ORDER BY a.balance DESC NULLS LAST;

-- 5. CDC OPERATIONS ANALYTICS
-- ========================================

-- CDC operations summary by table and operation type
SELECT 
    source_table,
    op as operation_type,
    COUNT(*) as operation_count,
    MIN(from_unixtime(ts_ms/1000)) as first_operation,
    MAX(from_unixtime(ts_ms/1000)) as last_operation
FROM (
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.users
    UNION ALL
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.accounts
) combined_events
GROUP BY source_table, op
ORDER BY source_table, operation_count DESC;

-- 6. REAL-TIME BUSINESS METRICS
-- ========================================

-- Portfolio summary by currency
WITH latest_accounts AS (
    SELECT 
        json_extract_scalar(data, '$.currency') as currency,
        CAST(json_extract_scalar(data, '$.balance') as DECIMAL(10,2)) as balance,
        ROW_NUMBER() OVER (PARTITION BY json_extract_scalar(data, '$.id') ORDER BY ts_ms DESC) as rn
    FROM iceberg.raw_data.accounts 
    WHERE op IN ('c', 'u')
)
SELECT 
    currency,
    COUNT(*) as account_count,
    SUM(balance) as total_balance,
    AVG(balance) as avg_balance,
    MIN(balance) as min_balance,
    MAX(balance) as max_balance
FROM latest_accounts 
WHERE rn = 1
GROUP BY currency
ORDER BY total_balance DESC;

-- 7. TIME-SERIES ANALYSIS
-- ========================================

-- CDC events over time (hourly breakdown)
SELECT 
    date_trunc('hour', from_unixtime(ts_ms/1000)) as event_hour,
    source_table,
    op as operation_type,
    COUNT(*) as event_count
FROM (
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.users
    UNION ALL
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.accounts
) combined_events
GROUP BY date_trunc('hour', from_unixtime(ts_ms/1000)), source_table, op
ORDER BY event_hour DESC, source_table, op; 