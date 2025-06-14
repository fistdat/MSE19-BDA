# 📊 Metabase Production Setup Guide
## CDC Data Lakehouse - Complete Implementation

### 🎯 Overview
This guide provides step-by-step instructions for implementing a production-ready Metabase instance with real-time CDC data visualization, advanced analytics, and enterprise-grade security.

---

## 🚀 Phase 1: Initial Setup & Configuration

### 1.1. System Requirements
- **Memory**: 4GB RAM minimum (8GB recommended)
- **Storage**: 20GB available space
- **Network**: Docker network access to all services
- **Ports**: 3001 (Metabase), 5432 (PostgreSQL), 8080 (Trino)

### 1.2. First-Time Setup
1. **Access Metabase Interface**
   ```bash
   open http://localhost:3001
   ```

2. **Initial Configuration Screen**
   - Language: English (US)
   - First Name: `CDC`
   - Last Name: `Administrator`
   - Email: `admin@cdc-lakehouse.com`
   - Company: `CDC Data Lakehouse Demo`
   - Password: `DataLakehouse2025!`

3. **Usage Data Preference**
   - Select: "No thanks" (for demo purposes)
   - Click "Next"

### 1.3. Database Connection Setup

#### Option A: PostgreSQL (Real-time Source)
```yaml
Connection Name: CDC Source Database
Database Type: PostgreSQL
Host: postgres
Port: 5432
Database Name: bank
Username: postgres
Password: password
```

**Test Steps:**
1. Click "Test Database Connection"
2. Verify "Successfully connected" message
3. Click "Next" → "Take me to Metabase"

#### Option B: Trino (Data Lake Analytics)
```yaml
Connection Name: Iceberg Data Lake
Database Type: Other
JDBC URL: jdbc:trino://trino:8080/iceberg/raw_data
Username: commander
Password: (leave empty)
Additional JDBC connection string options: (leave empty)
```

**Advanced Configuration:**
```properties
# Connection Pool Settings
Maximum pool size: 15
Login timeout: 10 seconds
```

---

## 📈 Phase 2: Dashboard Creation

### 2.1. Executive Dashboard

#### Dashboard Layout
- **Grid Size**: 4x3 (12 widgets maximum)
- **Refresh Rate**: 1 minute
- **Access Level**: Executive role only

#### Widget 1: Total Portfolio Value
```sql
-- PostgreSQL Version
SELECT 
    currency,
    SUM(balance) as total_balance,
    COUNT(*) as account_count
FROM accounts 
GROUP BY currency 
ORDER BY total_balance DESC;
```

**Visualization Settings:**
- Chart Type: **Donut Chart**
- Metric: `total_balance`
- Dimension: `currency`
- Color Scheme: Business colors

#### Widget 2: Account Tier Distribution
```sql
-- Business Tier Classification
SELECT 
    CASE 
        WHEN balance >= 10000 THEN 'Premium+'
        WHEN balance >= 5000 THEN 'Premium'
        WHEN balance >= 1000 THEN 'Standard'
        ELSE 'Basic'
    END as tier,
    COUNT(*) as count,
    ROUND(AVG(balance), 2) as avg_balance
FROM accounts 
GROUP BY tier
ORDER BY avg_balance DESC;
```

**Visualization Settings:**
- Chart Type: **Bar Chart**
- X-axis: `tier`
- Y-axis: `count`
- Color: `avg_balance` (gradient)

#### Widget 3: Top 10 Customers
```sql
-- High-Value Customer Analysis
SELECT 
    u.name,
    u.email,
    a.balance,
    a.currency,
    CASE 
        WHEN a.balance >= 10000 THEN '⭐ Premium+'
        WHEN a.balance >= 5000 THEN '🥈 Premium'
        ELSE '🥉 Standard'
    END as status
FROM users u 
JOIN accounts a ON u.id = a.user_id 
ORDER BY a.balance DESC 
LIMIT 10;
```

**Visualization Settings:**
- Chart Type: **Table**
- Enable: Row striping, sorting
- Format: Currency columns with locale

### 2.2. Operations Dashboard (Trino/Iceberg)

#### Widget 4: CDC Event Volume
```sql
-- Real-time CDC Monitoring
SELECT 
    source_table,
    op as operation,
    COUNT(*) as events,
    MAX(from_unixtime(ts_ms/1000)) as latest_event
FROM (
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.users
    UNION ALL
    SELECT source_table, op, ts_ms FROM iceberg.raw_data.accounts
) 
GROUP BY source_table, op
ORDER BY events DESC;
```

**Visualization Settings:**
- Chart Type: **Line Chart**
- X-axis: `latest_event` (time-based)
- Y-axis: `events`
- Group by: `source_table`

#### Widget 5: Data Freshness Monitor
```sql
-- Data Lake Freshness Tracking
SELECT 
    'users' as table_name,
    COUNT(*) as total_records,
    MAX(from_unixtime(ts_ms/1000)) as last_update,
    DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) as seconds_since_update
FROM iceberg.raw_data.users
UNION ALL
SELECT 
    'accounts' as table_name,
    COUNT(*) as total_records,
    MAX(from_unixtime(ts_ms/1000)) as last_update,
    DATE_DIFF('second', MAX(from_unixtime(ts_ms/1000)), NOW()) as seconds_since_update
FROM iceberg.raw_data.accounts;
```

**Visualization Settings:**
- Chart Type: **Gauge**
- Metric: `seconds_since_update`
- Ranges: Green (0-30), Yellow (30-60), Red (60+)

#### Widget 6: Real-time Portfolio Analytics
```sql
-- Advanced Iceberg Analytics
WITH latest_accounts AS (
    SELECT 
        json_extract_scalar(data, '$.user_id') as user_id,
        json_extract_scalar(data, '$.currency') as currency,
        CAST(json_extract_scalar(data, '$.balance') as DECIMAL(10,2)) as balance
    FROM iceberg.raw_data.accounts 
    WHERE op IN ('c', 'u')
),
latest_users AS (
    SELECT 
        json_extract_scalar(data, '$.id') as id,
        json_extract_scalar(data, '$.name') as name,
        json_extract_scalar(data, '$.email') as email
    FROM iceberg.raw_data.users 
    WHERE op IN ('c', 'u')
)
SELECT 
    lu.name,
    la.currency,
    la.balance,
    CASE 
        WHEN la.balance >= 10000 THEN 'Premium+'
        WHEN la.balance >= 5000 THEN 'Premium'
        WHEN la.balance >= 1000 THEN 'Standard'
        ELSE 'Basic'
    END as tier
FROM latest_accounts la
JOIN latest_users lu ON la.user_id = lu.id
ORDER BY la.balance DESC;
```

### 2.3. Analytics Dashboard

#### Widget 7: Customer Growth Trends
```sql
-- Customer Acquisition Analysis
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as new_customers,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('day', created_at)) as cumulative_customers
FROM users 
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date;
```

#### Widget 8: Currency Distribution Over Time
```sql
-- Multi-Currency Portfolio Analysis
SELECT 
    DATE_TRUNC('week', a.created_at) as week,
    a.currency,
    SUM(a.balance) as total_balance,
    COUNT(*) as account_count,
    AVG(a.balance) as avg_balance
FROM accounts a
GROUP BY DATE_TRUNC('week', a.created_at), a.currency
ORDER BY week DESC, total_balance DESC;
```

---

## ⚡ Phase 3: Auto-Refresh Configuration

### 3.1. Dashboard-Specific Settings

#### Executive Dashboard
```yaml
Auto-refresh: Enabled
Refresh Interval: 60 seconds
Cache TTL: 30 seconds
Background Sync: Enabled
Error Handling: Graceful degradation
```

#### Operations Dashboard
```yaml
Auto-refresh: Enabled
Refresh Interval: 30 seconds
Cache TTL: 15 seconds
Real-time Updates: Priority
Alert Thresholds: Enabled
```

#### Analytics Dashboard
```yaml
Auto-refresh: Manual
Refresh Interval: 300 seconds (5 minutes)
Cache TTL: 120 seconds
Heavy Queries: Optimized scheduling
```

### 3.2. Performance Optimization

#### Query Optimization
1. **Index Usage Verification**
   ```sql
   -- Check query execution plans
   EXPLAIN ANALYZE SELECT currency, SUM(balance) FROM accounts GROUP BY currency;
   ```

2. **Cache Strategy Implementation**
   - Enable question-level caching
   - Set appropriate TTL based on data volatility
   - Use dashboard-level cache inheritance

3. **Connection Pooling**
   ```yaml
   PostgreSQL Settings:
     Max connections: 15
     Initial pool size: 5
     Connection timeout: 30s
   
   Trino Settings:
     Max connections: 10
     Query timeout: 300s
     Result timeout: 60s
   ```

### 3.3. Advanced Refresh Configuration

#### Conditional Refresh Rules
```javascript
// Custom refresh logic (Admin → Settings → Advanced)
if (dashboard.name === "Executive") {
    refresh.interval = 60; // 1 minute
    refresh.priority = "high";
} else if (dashboard.name === "Operations") {
    refresh.interval = 30; // 30 seconds
    refresh.priority = "critical";
}
```

#### Error Handling
```yaml
Retry Policy:
  Max Attempts: 3
  Backoff Strategy: Exponential
  Fallback: Show cached data
  Notification: Alert admin on failure
```

---

## 🔒 Phase 4: Security & Performance

### 4.1. SSL/TLS Configuration
```yaml
# metabase.properties
MB_JETTY_SSL: true
MB_JETTY_SSL_PORT: 3443
MB_JETTY_SSL_KEYSTORE: /path/to/keystore.jks
MB_JETTY_SSL_KEYSTORE_PASSWORD: ${SSL_KEYSTORE_PASSWORD}
```

### 4.2. Database Security
```sql
-- Create read-only user for Metabase
CREATE ROLE metabase_readonly;
GRANT CONNECT ON DATABASE bank TO metabase_readonly;
GRANT USAGE ON SCHEMA public TO metabase_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_readonly;
```

### 4.3. Performance Monitoring
```yaml
Monitoring Dashboards:
  - Query execution times
  - Database connection usage
  - Cache hit rates
  - User session analytics
  - System resource utilization
```

---

## 📱 Phase 5: Mobile & Embedding

### 5.1. Mobile Dashboard Optimization
- **Responsive Design**: Enable mobile-first layout
- **Touch Optimization**: Large click targets
- **Data Compression**: Minimize mobile data usage
- **Offline Support**: Cache critical dashboards

### 5.2. Embedding Configuration
```javascript
// Public embedding example
<iframe
    src="http://localhost:3001/public/dashboard/12345?theme=transparent"
    frameborder="0"
    width="800"
    height="600"
    allowtransparency>
</iframe>
```

---

## 🎯 Phase 6: Testing & Validation

### 6.1. Automated Testing Script
```bash
#!/bin/bash
# metabase_validation.sh

echo "🧪 Testing Metabase Configuration..."

# Test database connections
curl -s "http://localhost:3001/api/database" | jq '.[] | {name, engine, status}'

# Test dashboard refresh
curl -s "http://localhost:3001/api/dashboard/1/query" | jq '.status'

# Test user authentication
curl -s -X POST "http://localhost:3001/api/session" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@cdc-lakehouse.com","password":"DataLakehouse2025!"}'

echo "✅ All tests completed"
```

### 6.2. Performance Benchmarks
- **Dashboard Load Time**: < 2 seconds
- **Query Response Time**: < 1 second (simple), < 5 seconds (complex)
- **Concurrent Users**: Support 50+ simultaneous users
- **Data Freshness**: < 30 seconds end-to-end CDC latency

---

## 🚀 Phase 7: Production Deployment

### 7.1. Production Checklist
- [ ] SSL certificates configured
- [ ] Database connections secured
- [ ] User roles and permissions set
- [ ] Dashboards tested and validated
- [ ] Auto-refresh configured
- [ ] Monitoring alerts set up
- [ ] Backup procedures established
- [ ] Documentation updated

### 7.2. Monitoring & Alerting
```yaml
Critical Alerts:
  - Database connection failures
  - Query timeout errors
  - Dashboard refresh failures
  - User authentication issues
  - System resource exhaustion

Warning Alerts:
  - Slow query performance
  - Cache miss rates
  - High concurrent user load
  - Data freshness delays
```

### 7.3. Maintenance Procedures
```bash
# Daily maintenance script
#!/bin/bash
# metabase_maintenance.sh

# Clean old cache entries
docker exec metabase java -jar metabase.jar reset-cache

# Verify database connections
docker exec metabase curl -s localhost:3000/api/health

# Update query metadata
docker exec metabase java -jar metabase.jar sync-database

echo "🔧 Maintenance completed: $(date)"
```

---

## 📚 Appendix

### A. Troubleshooting Guide
- **Connection Issues**: Check network, credentials, firewall
- **Performance Issues**: Optimize queries, increase resources
- **Refresh Failures**: Verify cache settings, check error logs
- **User Access Issues**: Review permissions, check group memberships

### B. Advanced Configuration
- Custom themes and branding
- Advanced SQL functions
- API integration examples
- Third-party plugin installation

### C. Security Best Practices
- Regular security updates
- Access audit procedures
- Data governance policies
- Compliance requirements (GDPR, SOX, etc.)

---

**📞 Support Contact**: admin@cdc-lakehouse.com  
**📖 Documentation**: [Internal Wiki Link]  
**🔧 Emergency Procedures**: [Incident Response Guide]

---
*Last Updated: $(date)*  
*Version: 1.0 Production* 