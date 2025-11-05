#!/usr/bin/env python3
"""
Franklin County Absentee Ballot Voter Viewer - Flask Web Application
"""

from flask import Flask, render_template_string, request
import mysql.connector
from datetime import datetime

app = Flask(__name__)

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'R_250108_z',
    'database': 'ohsosvoterfiles'
}

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Franklin County Absentee Voters</title>
    <link rel="icon" type="image/x-icon" href="favicon.ico">
    <link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f7fa;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            display: flex;
            align-items: center;
            gap: 20px;
        }
        
        .header-logo {
            width: 80px;
            height: 80px;
            object-fit: contain;
            filter: drop-shadow(0 2px 4px rgba(0,0,0,0.2));
        }
        
        .header-content {
            flex: 1;
        }
        
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header p { opacity: 0.9; font-size: 14px; }
        
        .controls {
            padding: 25px 30px;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
            display: flex;
            align-items: center;
            gap: 15px;
        }
        
        .controls label {
            font-weight: 600;
            font-size: 14px;
            color: #495057;
        }
        
        .controls select {
            padding: 10px 15px;
            border: 2px solid #dee2e6;
            border-radius: 6px;
            font-size: 14px;
            background: white;
            cursor: pointer;
            min-width: 300px;
        }
        
        .stats {
            padding: 15px 30px;
            background: #fff3cd;
            border-bottom: 1px solid #ffeaa7;
            font-size: 14px;
            color: #856404;
        }
        
        .table-container {
            overflow-x: auto;
            padding: 20px 30px;
            max-height: 600px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        
        th {
            background: #f8f9fa;
            color: #495057;
            font-weight: 600;
            text-align: left;
            padding: 12px 10px;
            border-bottom: 2px solid #dee2e6;
            position: sticky;
            top: 0;
        }
        
        td {
            padding: 12px 10px;
            border-bottom: 1px solid #e9ecef;
        }
        
        tr:hover { background: #f8f9fa; }
        
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .badge-val { background: #d4edda; color: #155724; }
        .badge-outstanding { background: #fff3cd; color: #856404; }
        .badge-problem { background: #f8d7da; color: #721c24; }
        
        .party-D { color: #0066cc; font-weight: 600; }
        .party-R { color: #cc0000; font-weight: 600; }
        .party-U { color: #666666; font-weight: 600; }
        
        .chart-section {
            padding: 30px;
            background: white;
            border-bottom: 1px solid #e9ecef;
        }
        
        .chart-container {
            max-width: 500px;
            margin: 0 auto;
            position: relative;
        }
        
        .chart-title {
            text-align: center;
            font-size: 18px;
            font-weight: 600;
            color: #495057;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="fearsomefrog.png" alt="Logo" class="header-logo">
            <div class="header-content">
                <h1>🗳️ Franklin County Absentee Voters</h1>
                <p>Mail-in ballot tracking and status viewer</p>
                <p style="margin-top: 10px; font-size: 13px; opacity: 0.85;">
                    📅 Data as of: <strong>November 4, 2025</strong>
                </p>
            </div>
        </div>
        
        <div class="controls">
            <label for="status-filter">Filter by Status:</label>
            <select id="status-filter" onchange="window.location.href='?status='+this.value">
                <option value="ALL" {{ 'selected' if selected_status == 'ALL' else '' }}>
                    All Voters ({{ '{:,}'.format(total_count) }})
                </option>
                {% for status in statuses %}
                <option value="{{ status.value }}" {{ 'selected' if selected_status == status.value else '' }}>
                    {{ status.display }} ({{ '{:,}'.format(status.count) }})
                </option>
                {% endfor %}
            </select>
        </div>
        
        <div class="chart-section">
            <div class="chart-title">Ballot Status Distribution</div>
            <div class="chart-container">
                <canvas id="statusChart"></canvas>
            </div>
        </div>
        
        <div class="stats">
            <strong>Showing:</strong> {{ '{:,}'.format(voters|length) }} voters{{ ' (limited to 1000)' if voters|length >= 1000 else '' }}
        </div>
        
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Party</th>
                        <th>Address</th>
                        <th>City</th>
                        <th>Precinct</th>
                        <th>Requested</th>
                        <th>Returned</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    {% for voter in voters %}
                    <tr>
                        <td>
                            <strong>{{ voter.last_name }}</strong>, {{ voter.first_name }}
                            {% if voter.middle_name %}{{ voter.middle_name[0] }}.{% endif %}
                        </td>
                        <td><span class="party-{{ voter.party }}">{{ voter.party }}</span></td>
                        <td>{{ voter.address_line_1 }}</td>
                        <td>{{ voter.city }}, {{ voter.state }} {{ voter.zip }}</td>
                        <td style="font-size: 11px;">{{ voter.precinct_name }}</td>
                        <td>{{ voter.date_requested.strftime('%m/%d/%Y') if voter.date_requested else '-' }}</td>
                        <td>{{ voter.date_returned.strftime('%m/%d/%Y') if voter.date_returned else '-' }}</td>
                        <td>
                            {% set badge_class = 'badge badge-val' if voter.status_display == 'VAL' 
                                                 else 'badge badge-outstanding' if voter.status_display == 'Outstanding'
                                                 else 'badge badge-problem' %}
                            <span class="{{ badge_class }}">{{ voter.status_display }}</span>
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script>
        // Status Chart Data
        const statusData = {{ statuses | tojson }};
        
        // Define colors for each status
        const statusColors = {
            'VAL': '#28a745',           // Green
            'Outstanding': '#ffc107',   // Yellow/Amber
            'IDNOMATCH': '#dc3545',     // Red
            'REFUSED': '#dc3545',       // Red
            'NOSIG': '#fd7e14',         // Orange
            'NOID': '#fd7e14',          // Orange
            'MOVED': '#6c757d',         // Gray
            'NAMECHG': '#6c757d',       // Gray
            'SPRET': '#17a2b8',         // Teal
            'ABS': '#ffc107'            // Yellow
        };
        
        // Prepare chart data
        const labels = statusData.map(s => s.display);
        const values = statusData.map(s => parseInt(s.count));  // Ensure numbers
        const colors = statusData.map(s => statusColors[s.display] || '#6c757d');
        
        // Create the pie chart
        const ctx = document.getElementById('statusChart').getContext('2d');
        const statusChart = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    backgroundColor: colors,
                    borderColor: '#ffffff',
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        position: 'right',
                        labels: {
                            font: {
                                size: 12
                            },
                            padding: 15,
                            generateLabels: function(chart) {
                                const data = chart.data;
                                if (data.labels.length && data.datasets.length) {
                                    return data.labels.map((label, i) => {
                                        const value = data.datasets[0].data[i];
                                        const total = data.datasets[0].data.reduce((a, b) => a + b, 0);
                                        const percentage = ((value / total) * 100).toFixed(1);
                                        return {
                                            text: `${label}: ${value.toLocaleString()} (${percentage}%)`,
                                            fillStyle: data.datasets[0].backgroundColor[i],
                                            hidden: false,
                                            index: i
                                        };
                                    });
                                }
                                return [];
                            }
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.parsed;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                return `${label}: ${value.toLocaleString()} (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
'''

def get_db_connection():
    """Create and return a database connection"""
    return mysql.connector.connect(**DB_CONFIG)

@app.route('/')
def index():
    selected_status = request.args.get('status', 'ALL')
    
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Get status counts
    cursor.execute("""
        SELECT 
            CASE 
                WHEN status IS NULL OR status = '' THEN 'Outstanding'
                ELSE status 
            END as status_display,
            COALESCE(status, '') as status_value,
            COUNT(*) as count 
        FROM fcabs2025 
        GROUP BY status 
        ORDER BY count DESC
    """)
    statuses = [{'display': row['status_display'], 
                 'value': row['status_value'], 
                 'count': row['count']} 
                for row in cursor.fetchall()]
    total_count = sum(s['count'] for s in statuses)
    
    # Build voter query
    voter_query = """
        SELECT 
            local_id, first_name, middle_name, last_name, party,
            city_or_village, precinct_name, address_line_1,
            city, state, zip, date_requested, date_returned,
            CASE 
                WHEN status IS NULL OR status = '' THEN 'Outstanding'
                ELSE status 
            END as status_display
        FROM fcabs2025
    """
    
    # Add WHERE clause
    if selected_status != 'ALL':
        if selected_status == '' or selected_status == 'Outstanding':
            voter_query += " WHERE (status IS NULL OR status = '')"
        else:
            voter_query += f" WHERE status = '{selected_status}'"
    
    voter_query += " ORDER BY last_name, first_name LIMIT 1000"
    
    cursor.execute(voter_query)
    voters = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template_string(
        HTML_TEMPLATE,
        voters=voters,
        statuses=statuses,
        total_count=total_count,
        selected_status=selected_status
    )

if __name__ == '__main__':
    print("Starting Franklin County Voter Viewer...")
    print("Access the application at: http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)

