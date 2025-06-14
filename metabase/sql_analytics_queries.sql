-- ===============================================
-- CDC DATA LAKEHOUSE - SQL ANALYTICS QUERIES
-- Complete Query Library for Metabase Dashboards
-- ===============================================

-- =================== EXECUTIVE DASHBOARD QUERIES ===================

-- Query 1: Total Portfolio Value by Currency
-- Use Case: Executive overview of total assets
-- Data Source: PostgreSQL (Real-time)
SELECT 
    currency,
    COUNT(*) as account_count,
    SUM(balance) as total_balance,
    AVG(balance) as avg_balance,
    MIN(balance) as min_balance,
    MAX(balance) as max_balance,
    ROUND(SUM(balance) * 100.0 / (SELECT SUM(balance) FROM accounts), 2) as percentage_of_total
FROM accounts 
WHERE balance > 0
GROUP BY currency 
ORDER BY total_balance DESC;

-- Query 2: Account Tier Distribution
-- Use Case: Customer segmentation analysis
-- Data Source: PostgreSQL (Real-time)
SELECT 
    CASE 
        WHEN balance >= 50000 THEN 'Enterprise'
        WHEN balance >= 10000 THEN 'Premium+'
        WHEN balance >= 5000 THEN 'Premium'
        WHEN balance >= 1000 THEN 'Standard'
        ELSE 'Basic'
    END as tier,
    COUNT(*) as account_count,
    ROUND(AVG(balance), 2) as avg_balance,
    SUM(balance) as total_balance,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM accounts), 2) as percentage_of_accounts
FROM accounts 
GROUP BY tier
ORDER BY avg_balance DESC;

-- Query 3: Top 10 High-Value Customers
-- Use Case: VIP customer identification
-- Data Source: PostgreSQL (Real-time)
SELECT 
    u.name,
    u.email,
    a.balance,
    a.currency,
    CASE 
        WHEN a.balance >= 50000 THEN '💎 Enterprise'
        WHEN a.balance >= 10000 THEN '⭐ Premium+'
        WHEN a.balance >= 5000 THEN '🥈 Premium'
        ELSE '🥉 Standard'
    END as status,
    a.created_at as account_opened,
    DATE_PART('day', NOW() - a.created_at) as days_as_customer
FROM users u 
JOIN accounts a ON u.id = a.user_id 
ORDER BY a.balance DESC 
LIMIT 10;

-- Query 4: Monthly Growth Trends
-- Use Case: Business growth tracking
-- Data Source: PostgreSQL (Real-time)
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as new_accounts,
    SUM(balance) as new_deposits,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', created_at)) as cumulative_accounts,
    SUM(SUM(balance)) OVER (ORDER BY DATE_TRUNC('month', created_at)) as cumulative_deposits
FROM accounts 
WHERE created_at >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month;

-- =================== OPERATIONS DASHBOARD QUERIES ===================

-- Query 5: CDC Event Volume Monitoring
-- Use Case: Real-time CDC pipeline health
-- Data Source: Trino (Iceberg)
SELECT 
    source_table,
    op as operation,
    COUNT(*) as event_count,
    MIN(from_unixtime(ts_ms/1000)) as earliest_event,
    MAX(from_unixtime(ts_ms/1000)) as latest_event,
    COUNT(DISTINCT DATE_TRUNC('hour', from_unixtime(ts_ms/1000))) as active_hours
FROM (
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.users
    UNION ALL
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.accounts
) 
WHERE from_unixtime(ts_ms/1000) >= NOW() - INTERVAL '24' HOUR
GROUP BY source_table, op
ORDER BY event_count DESC;

-- Query 6: Data Freshness Monitor
-- Use Case: Data pipeline latency tracking
-- Data Source: Trino (Iceberg)
SELECT 
    'users' as table_name,
    COUNT(*) as total_records,
    MAX(from_unixtime(ts_ms/1000)) as last_update,
    DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) as seconds_behind,
    CASE 
        WHEN DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) <= 30 THEN '🟢 Fresh'
        WHEN DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) <= 60 THEN '🟡 Delayed'
        ELSE '🔴 Stale'
    END as freshness_status
FROM iceberg.raw_data.users
UNION ALL
SELECT 
    'accounts' as table_name,
    COUNT(*) as total_records,
    MAX(from_unixtime(ts_ms/1000)) as last_update,
    DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) as seconds_behind,
    CASE 
        WHEN DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) <= 30 THEN '🟢 Fresh'
        WHEN DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) <= 60 THEN '🟡 Delayed'
        ELSE '🔴 Stale'
    END as freshness_status
FROM iceberg.raw_data.accounts;

-- Query 7: Error Rate Analysis
-- Use Case: Data quality monitoring
-- Data Source: Trino (Iceberg)
WITH error_analysis AS (
    SELECT 
        source_table,
        COUNT(*) as total_events,
        COUNT(CASE WHEN op = 'd' THEN 1 END) as delete_events,
        COUNT(CASE WHEN op = 'c' THEN 1 END) as create_events,
        COUNT(CASE WHEN op = 'u' THEN 1 END) as update_events,
        COUNT(CASE WHEN data IS NULL OR data = '' THEN 1 END) as null_data_events
    FROM (
        SELECT source_table, op, data FROM iceberg.raw_data.users
        UNION ALL
        SELECT source_table, op, data FROM iceberg.raw_data.accounts
    )
    WHERE from_unixtime(ts_ms/1000) >= NOW() - INTERVAL '1' HOUR
    GROUP BY source_table
)
SELECT 
    source_table,
    total_events,
    create_events,
    update_events,
    delete_events,
    null_data_events,
    ROUND(null_data_events * 100.0 / total_events, 2) as error_rate_percentage
FROM error_analysis
ORDER BY error_rate_percentage DESC;

-- Query 8: Hourly Event Processing Rate
-- Use Case: Performance monitoring
-- Data Source: Trino (Iceberg)
SELECT 
    DATE_TRUNC('hour', from_unixtime(ts_ms/1000)) as hour,
    source_table,
    COUNT(*) as events_processed,
    COUNT(DISTINCT ts_ms) as unique_timestamps,
    AVG(CAST(ts_ms as DOUBLE)) as avg_timestamp_ms
FROM (
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.users
    UNION ALL
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.accounts
)
WHERE from_unixtime(ts_ms/1000) >= NOW() - INTERVAL '24' HOUR
GROUP BY DATE_TRUNC('hour', from_unixtime(ts_ms/1000)), source_table
ORDER BY hour DESC, source_table;

-- =================== ANALYTICS DASHBOARD QUERIES ===================

-- Query 9: Customer Journey Analysis
-- Use Case: User behavior tracking
-- Data Source: PostgreSQL (Real-time)
WITH customer_metrics AS (
    SELECT 
        u.id,
        u.name,
        u.email,
        u.created_at as signup_date,
        a.balance,
        a.currency,
        a.created_at as account_opened,
        DATE_PART('day', a.created_at - u.created_at) as days_to_account_creation,
        CASE 
            WHEN a.created_at IS NULL THEN 'No Account'
            WHEN DATE_PART('day', a.created_at - u.created_at) = 0 THEN 'Same Day'
            WHEN DATE_PART('day', a.created_at - u.created_at) <= 7 THEN 'Within Week'
            WHEN DATE_PART('day', a.created_at - u.created_at) <= 30 THEN 'Within Month'
            ELSE 'After Month'
        END as account_creation_timing
    FROM users u
    LEFT JOIN accounts a ON u.id = a.user_id
)
SELECT 
    account_creation_timing,
    COUNT(*) as user_count,
    COUNT(CASE WHEN balance IS NOT NULL THEN 1 END) as users_with_accounts,
    AVG(CASE WHEN balance IS NOT NULL THEN balance END) as avg_balance,
    SUM(CASE WHEN balance IS NOT NULL THEN balance ELSE 0 END) as total_balance
FROM customer_metrics
GROUP BY account_creation_timing
ORDER BY 
    CASE account_creation_timing
        WHEN 'Same Day' THEN 1
        WHEN 'Within Week' THEN 2
        WHEN 'Within Month' THEN 3
        WHEN 'After Month' THEN 4
        WHEN 'No Account' THEN 5
    END;

-- Query 10: Currency Distribution Over Time
-- Use Case: Geographic/currency trend analysis
-- Data Source: PostgreSQL (Real-time)
SELECT 
    DATE_TRUNC('week', a.created_at) as week,
    a.currency,
    COUNT(*) as new_accounts,
    SUM(a.balance) as total_deposits,
    AVG(a.balance) as avg_account_size,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY DATE_TRUNC('week', a.created_at)) as percentage_of_week
FROM accounts a
WHERE a.created_at >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', a.created_at), a.currency
ORDER BY week DESC, total_deposits DESC;

-- Query 11: Advanced Portfolio Analytics (Iceberg)
-- Use Case: Real-time portfolio management
-- Data Source: Trino (Iceberg)
WITH latest_accounts AS (
    SELECT 
        json_extract_scalar(data, '$.id') as account_id,
        json_extract_scalar(data, '$.user_id') as user_id,
        json_extract_scalar(data, '$.currency') as currency,
        CAST(json_extract_scalar(data, '$.balance') as DECIMAL(15,2)) as balance,
        from_unixtime(ts_ms/1000) as last_updated
    FROM iceberg.raw_data.accounts 
    WHERE op IN ('c', 'u')
),
latest_users AS (
    SELECT 
        json_extract_scalar(data, '$.id') as user_id,
        json_extract_scalar(data, '$.name') as name,
        json_extract_scalar(data, '$.email') as email,
        from_unixtime(ts_ms/1000) as last_updated
    FROM iceberg.raw_data.users 
    WHERE op IN ('c', 'u')
),
portfolio_summary AS (
    SELECT 
        lu.name,
        lu.email,
        la.currency,
        la.balance,
        la.last_updated as account_last_updated,
        CASE 
            WHEN la.balance >= 50000 THEN 'Enterprise'
            WHEN la.balance >= 10000 THEN 'Premium+'
            WHEN la.balance >= 5000 THEN 'Premium'
            WHEN la.balance >= 1000 THEN 'Standard'
            ELSE 'Basic'
        END as tier
    FROM latest_accounts la
    JOIN latest_users lu ON la.user_id = lu.user_id
)
SELECT 
    currency,
    tier,
    COUNT(*) as customer_count,
    SUM(balance) as total_balance,
    AVG(balance) as avg_balance,
    MIN(balance) as min_balance,
    MAX(balance) as max_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balance) as median_balance
FROM portfolio_summary
GROUP BY currency, tier
ORDER BY currency, 
    CASE tier 
        WHEN 'Enterprise' THEN 1
        WHEN 'Premium+' THEN 2
        WHEN 'Premium' THEN 3
        WHEN 'Standard' THEN 4
        WHEN 'Basic' THEN 5
    END;

-- =================== ADVANCED ANALYTICS QUERIES ===================

-- Query 12: Customer Lifetime Value Analysis
-- Use Case: CLV prediction and segmentation
-- Data Source: PostgreSQL (Real-time)
WITH customer_analysis AS (
    SELECT 
        u.id,
        u.name,
        u.email,
        u.created_at as customer_since,
        a.balance as current_balance,
        a.currency,
        DATE_PART('day', NOW() - u.created_at) as days_as_customer,
        CASE 
            WHEN DATE_PART('day', NOW() - u.created_at) = 0 THEN 1
            ELSE DATE_PART('day', NOW() - u.created_at)
        END as customer_lifetime_days
    FROM users u
    LEFT JOIN accounts a ON u.id = a.user_id
),
clv_metrics AS (
    SELECT 
        *,
        CASE WHEN customer_lifetime_days > 0 THEN current_balance / customer_lifetime_days ELSE 0 END as daily_value,
        current_balance * (365.0 / GREATEST(customer_lifetime_days, 1)) as projected_annual_value
    FROM customer_analysis
    WHERE current_balance IS NOT NULL
)
SELECT 
    CASE 
        WHEN projected_annual_value >= 100000 THEN 'High Value (>100K)'
        WHEN projected_annual_value >= 50000 THEN 'Medium-High Value (50K-100K)'
        WHEN projected_annual_value >= 20000 THEN 'Medium Value (20K-50K)'
        WHEN projected_annual_value >= 5000 THEN 'Low-Medium Value (5K-20K)'
        ELSE 'Low Value (<5K)'
    END as clv_segment,
    COUNT(*) as customer_count,
    AVG(current_balance) as avg_current_balance,
    AVG(projected_annual_value) as avg_projected_annual_value,
    SUM(current_balance) as total_current_balance,
    AVG(days_as_customer) as avg_customer_lifetime_days
FROM clv_metrics
GROUP BY clv_segment
ORDER BY avg_projected_annual_value DESC;

-- Query 13: Cohort Analysis
-- Use Case: Customer retention and behavior tracking
-- Data Source: PostgreSQL (Real-time)
WITH user_cohorts AS (
    SELECT 
        u.id,
        u.email,
        DATE_TRUNC('month', u.created_at) as cohort_month,
        DATE_TRUNC('month', a.created_at) as account_month,
        a.balance,
        a.currency
    FROM users u
    LEFT JOIN accounts a ON u.id = a.user_id
),
cohort_data AS (
    SELECT 
        cohort_month,
        account_month,
        COUNT(DISTINCT id) as users,
        COUNT(DISTINCT CASE WHEN balance IS NOT NULL THEN id END) as users_with_accounts,
        AVG(balance) as avg_balance,
        SUM(balance) as total_balance
    FROM user_cohorts
    WHERE cohort_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
    GROUP BY cohort_month, account_month
)
SELECT 
    cohort_month,
    users as cohort_size,
    users_with_accounts,
    ROUND(users_with_accounts * 100.0 / users, 2) as account_creation_rate,
    ROUND(avg_balance, 2) as avg_balance,
    total_balance
FROM cohort_data
WHERE account_month IS NOT NULL
ORDER BY cohort_month DESC;

-- Query 14: Real-time System Performance
-- Use Case: Technical performance monitoring
-- Data Source: Trino (Iceberg)
WITH performance_metrics AS (
    SELECT 
        'iceberg.raw_data.users' as table_name,
        COUNT(*) as total_records,
        COUNT(DISTINCT DATE_TRUNC('hour', from_unixtime(ts_ms/1000))) as active_hours_today,
        MAX(from_unixtime(ts_ms/1000)) as latest_record,
        MIN(from_unixtime(ts_ms/1000)) as earliest_record_today
    FROM iceberg.raw_data.users
    WHERE from_unixtime(ts_ms/1000) >= DATE_TRUNC('day', NOW())
    
    UNION ALL
    
    SELECT 
        'iceberg.raw_data.accounts' as table_name,
        COUNT(*) as total_records,
        COUNT(DISTINCT DATE_TRUNC('hour', from_unixtime(ts_ms/1000))) as active_hours_today,
        MAX(from_unixtime(ts_ms/1000)) as latest_record,
        MIN(from_unixtime(ts_ms/1000)) as earliest_record_today
    FROM iceberg.raw_data.accounts
    WHERE from_unixtime(ts_ms/1000) >= DATE_TRUNC('day', NOW())
)
SELECT 
    table_name,
    total_records,
    active_hours_today,
    latest_record,
    DATE_DIFF('second', latest_record, NOW()) as seconds_since_last_record,
    CASE 
        WHEN DATE_DIFF('second', latest_record, NOW()) <= 30 THEN '🟢 Real-time'
        WHEN DATE_DIFF('second', latest_record, NOW()) <= 300 THEN '🟡 Near real-time'
        ELSE '🔴 Delayed'
    END as performance_status,
    ROUND(total_records / GREATEST(active_hours_today, 1), 0) as avg_records_per_hour
FROM performance_metrics
ORDER BY seconds_since_last_record;

-- =================== BUSINESS INTELLIGENCE QUERIES ===================

-- Query 15: Revenue Opportunity Analysis
-- Use Case: Business development insights
-- Data Source: PostgreSQL (Real-time)
WITH opportunity_analysis AS (
    SELECT 
        a.currency,
        COUNT(*) as total_accounts,
        SUM(a.balance) as current_total,
        AVG(a.balance) as current_avg,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY a.balance) as median_balance,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY a.balance) as p75_balance,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY a.balance) as p95_balance,
        MAX(a.balance) as max_balance
    FROM accounts a
    GROUP BY a.currency
)
SELECT 
    currency,
    total_accounts,
    ROUND(current_total, 2) as current_total_balance,
    ROUND(current_avg, 2) as current_avg_balance,
    ROUND(median_balance, 2) as median_balance,
    ROUND(p75_balance, 2) as p75_balance,
    ROUND(p95_balance, 2) as p95_balance,
    ROUND(max_balance, 2) as max_balance,
    -- Opportunity calculations
    ROUND((p75_balance - current_avg) * total_accounts, 2) as opportunity_to_p75,
    ROUND((median_balance * 2 - current_avg) * total_accounts, 2) as opportunity_double_median,
    ROUND(current_avg * 1.2 * total_accounts - current_total, 2) as opportunity_20_percent_growth
FROM opportunity_analysis
ORDER BY current_total_balance DESC;

-- =================== ALERTING QUERIES ===================

-- Query 16: High-Value Transaction Alerts
-- Use Case: Fraud detection and VIP monitoring
-- Data Source: PostgreSQL (Real-time)
SELECT 
    u.name,
    u.email,
    a.balance,
    a.currency,
    a.created_at as account_created,
    CASE 
        WHEN a.balance >= 100000 THEN '🚨 Ultra High Value'
        WHEN a.balance >= 50000 THEN '⚠️ High Value'
        WHEN a.balance >= 25000 THEN '📈 Significant'
        ELSE '💰 Notable'
    END as alert_level,
    DATE_PART('minute', NOW() - a.created_at) as minutes_ago
FROM users u
JOIN accounts a ON u.id = a.user_id
WHERE a.balance >= 25000 
    AND a.created_at >= NOW() - INTERVAL '1 hour'
ORDER BY a.balance DESC, a.created_at DESC;

-- Query 17: System Health Monitoring
-- Use Case: Operational alerts and monitoring
-- Data Source: Trino (Iceberg)
WITH health_check AS (
    SELECT 
        'users' as table_name,
        COUNT(*) as records_last_hour,
        MAX(from_unixtime(ts_ms/1000)) as last_update,
        DATE_DIFF('minute', MAX(from_unixtime(ts_ms/1000)), NOW()) as minutes_behind
    FROM iceberg.raw_data.users
    WHERE from_unixtime(ts_ms/1000) >= NOW() - INTERVAL '1' HOUR
    
    UNION ALL
    
    SELECT 
        'accounts' as table_name,
        COUNT(*) as records_last_hour,
        MAX(from_unixtime(ts_ms/1000)) as last_update,
        DATE_DIFF('minute', MAX(from_unixtime(ts_ms/1000)), NOW()) as minutes_behind
    FROM iceberg.raw_data.accounts
    WHERE from_unixtime(ts_ms/1000) >= NOW() - INTERVAL '1' HOUR
)
SELECT 
    table_name,
    records_last_hour,
    last_update,
    minutes_behind,
    CASE 
        WHEN minutes_behind <= 1 THEN '🟢 Healthy'
        WHEN minutes_behind <= 5 THEN '🟡 Warning'
        WHEN minutes_behind <= 15 THEN '🟠 Alert'
        ELSE '🔴 Critical'
    END as health_status,
    CASE 
        WHEN records_last_hour = 0 THEN '🔴 No Data'
        WHEN records_last_hour < 10 THEN '🟡 Low Volume'
        ELSE '🟢 Normal Volume'
    END as volume_status
FROM health_check
ORDER BY minutes_behind DESC;

-- =================== UTILITY QUERIES ===================

-- Query 18: Data Quality Assessment
-- Use Case: Data validation and quality monitoring
-- Data Source: Both PostgreSQL and Trino
-- PostgreSQL version:
SELECT 
    'PostgreSQL' as source,
    'users' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN email IS NULL OR email = '' THEN 1 END) as null_emails,
    COUNT(CASE WHEN name IS NULL OR name = '' THEN 1 END) as null_names,
    COUNT(DISTINCT email) as unique_emails,
    COUNT(*) - COUNT(DISTINCT email) as duplicate_emails
FROM users

UNION ALL

SELECT 
    'PostgreSQL' as source,
    'accounts' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN user_id IS NULL THEN 1 END) as null_user_ids,
    COUNT(CASE WHEN balance IS NULL OR balance < 0 THEN 1 END) as invalid_balances,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) - COUNT(DISTINCT user_id) as users_with_multiple_accounts
FROM accounts;

-- Query 19: Performance Benchmark
-- Use Case: System performance baseline
-- Data Source: Trino (Iceberg)
SELECT 
    'Performance Benchmark' as test_name,
    NOW() as test_timestamp,
    COUNT(*) as total_iceberg_records,
    COUNT(DISTINCT source_table) as tables_processed,
    MIN(from_unixtime(ts_ms/1000)) as earliest_data,
    MAX(from_unixtime(ts_ms/1000)) as latest_data,
    DATE_DIFF('hour', MIN(from_unixtime(ts_ms/1000)), MAX(from_unixtime(ts_ms/1000))) as data_span_hours
FROM (
    SELECT source_table, ts_ms FROM iceberg.raw_data.users
    UNION ALL
    SELECT source_table, ts_ms FROM iceberg.raw_data.accounts
);

-- ===============================================
-- END OF SQL ANALYTICS QUERIES LIBRARY
-- ===============================================

/*
QUERY CATEGORIES SUMMARY:
=========================

Executive Dashboard (4 queries):
- Portfolio value analysis
- Customer segmentation
- Top customers identification
- Growth trends

Operations Dashboard (4 queries):
- CDC event monitoring
- Data freshness tracking
- Error rate analysis
- Processing performance

Analytics Dashboard (3 queries):
- Customer journey analysis
- Currency trends
- Advanced portfolio analytics

Advanced Analytics (2 queries):
- Customer lifetime value
- Cohort analysis

Business Intelligence (1 query):
- Revenue opportunity analysis

Alerting (2 queries):
- High-value transaction alerts
- System health monitoring

Utility (2 queries):
- Data quality assessment
- Performance benchmarking

USAGE INSTRUCTIONS:
==================

1. Copy desired queries to Metabase query editor
2. Adjust table names and parameters as needed
3. Set appropriate refresh intervals for each dashboard
4. Configure alerts for operational queries
5. Use parameterized queries for dynamic filtering

PERFORMANCE NOTES:
=================

- PostgreSQL queries: < 1 second response time
- Trino/Iceberg queries: < 5 seconds response time
- Complex analytics: < 10 seconds response time
- Add indexes on frequently queried columns
- Use materialized views for heavy aggregations

*/ 