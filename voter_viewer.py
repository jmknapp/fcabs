#!/usr/bin/env python3
"""
Franklin County Absentee Ballot Voter Viewer - Flask Web Application
"""

from flask import Flask, render_template_string, request, jsonify
import mysql.connector
from datetime import datetime
from urllib.parse import urlencode
import os
from pathlib import Path

app = Flask(__name__)

# Load environment variables from .env file
def load_env(env_path):
    """Load environment variables from .env file"""
    if not env_path.exists():
        raise FileNotFoundError(
            f"Error: .env file not found at {env_path}. "
            "Please copy .env.example to .env and configure your database credentials."
        )
    
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue
            
            # Parse KEY=VALUE
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()
                # Only set if not already in environment
                if key not in os.environ:
                    os.environ[key] = value

# Load .env file from script directory
env_file = Path(__file__).parent / '.env'
load_env(env_file)

# Database configuration from environment variables
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASS'),
    'database': os.getenv('DB_NAME')
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
            flex-wrap: wrap;
            align-items: center;
            gap: 20px;
        }
        
        .filter-group {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .controls label {
            font-weight: 600;
            font-size: 14px;
            color: #495057;
            white-space: nowrap;
        }
        
        .controls select {
            padding: 10px 15px;
            border: 2px solid #dee2e6;
            border-radius: 6px;
            font-size: 14px;
            background: white;
            cursor: pointer;
            min-width: 250px;
            transition: border-color 0.2s;
        }
        
        .controls select:hover {
            border-color: #667eea;
        }
        
        .controls select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
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
            cursor: pointer;
            user-select: none;
            transition: background-color 0.2s;
        }
        
        th:hover {
            background: #e9ecef;
        }
        
        th.sortable::after {
            content: ' ⇅';
            opacity: 0.3;
            font-size: 12px;
        }
        
        th.sort-asc::after {
            content: ' ↑';
            opacity: 1;
            color: #667eea;
        }
        
        th.sort-desc::after {
            content: ' ↓';
            opacity: 1;
            color: #667eea;
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
                    📅 Data as of: <strong>November 5, 2025</strong>
                </p>
            </div>
        </div>
        
        <div class="controls">
            <div class="filter-group">
                <label for="status-filter">Filter by Status:</label>
                <select id="status-filter" onchange="applyFilters()">
                    <option value="ALL" {{ 'selected' if selected_status == 'ALL' else '' }}>
                        All Statuses ({{ '{:,}'.format(total_count) }})
                    </option>
                    {% for status in statuses %}
                    <option value="{{ status.value }}" {{ 'selected' if selected_status == status.value else '' }}>
                        {{ status.display }} ({{ '{:,}'.format(status.count) }})
                    </option>
                    {% endfor %}
                </select>
            </div>
            
            <div class="filter-group">
                <label for="party-filter">Filter by Party:</label>
                <select id="party-filter" onchange="applyFilters()">
                    <option value="ALL" {{ 'selected' if selected_party == 'ALL' else '' }}>
                        All Parties ({{ '{:,}'.format(total_count) }})
                    </option>
                    {% for party in parties %}
                    <option value="{{ party.party }}" {{ 'selected' if selected_party == party.party else '' }}>
                        {{ party.party }} ({{ '{:,}'.format(party.count) }})
                    </option>
                    {% endfor %}
                </select>
            </div>
        </div>
        
        <div class="chart-section">
            <div class="chart-title">
                Ballot Status Distribution
                {% if selected_party != 'ALL' %}
                    <span style="font-weight: normal; font-size: 16px; color: #6c757d;">
                        (Party: {{ selected_party }})
                    </span>
                {% endif %}
            </div>
            <div class="chart-container">
                <canvas id="statusChart"></canvas>
            </div>
        </div>
        
        <div class="stats">
            {{ '{:,}'.format(display_count) }} voters{{ showing_limit }}{{ show_all_button | safe }}
        </div>
        
        <div class="table-container">
            <table id="voterTable">
                <thead>
                    <tr>
                        {% set columns = [
                            ('name', 'Name'),
                            ('party', 'Party'),
                            ('address', 'Address'),
                            ('city', 'City'),
                            ('precinct', 'Precinct'),
                            ('requested', 'Requested'),
                            ('returned', 'Returned'),
                            ('status', 'Status')
                        ] %}
                        {% for col, label in columns %}
                            {% set params = {} %}
                            {% if selected_status != 'ALL' %}{% set _ = params.update({'status': selected_status}) %}{% endif %}
                            {% if selected_party != 'ALL' %}{% set _ = params.update({'party': selected_party}) %}{% endif %}
                            {% set _ = params.update({'sort': col}) %}
                            {% if sort_column == col %}
                                {% set _ = params.update({'dir': 'desc' if sort_direction == 'asc' else 'asc'}) %}
                                {% set sort_class = 'sort-asc' if sort_direction == 'asc' else 'sort-desc' %}
                            {% else %}
                                {% set _ = params.update({'dir': 'asc'}) %}
                                {% set sort_class = 'sortable' %}
                            {% endif %}
                            {% set query_string = [] %}
                            {% for key, value in params.items() %}
                                {% set _ = query_string.append(key ~ '=' ~ value) %}
                            {% endfor %}
                            <th class="{{ sort_class }}" data-url="?{{ query_string|join('&') }}">{{ label }}</th>
                        {% endfor %}
                    </tr>
                </thead>
                <tbody id="voterTableBody">
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
        function applyFilters() {
            const status = document.getElementById('status-filter').value;
            const party = document.getElementById('party-filter').value;
            
            const params = new URLSearchParams();
            if (status !== 'ALL') params.append('status', status);
            if (party !== 'ALL') params.append('party', party);
            
            window.location.href = '?' + params.toString();
        }
        
        // Status Chart Data (filtered by party if selected)
        const statusData = {{ chart_statuses | tojson }};
        
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
        
        // AJAX table sorting - refreshes only the table, not the whole page
        document.querySelectorAll('th.sortable, th.sort-asc, th.sort-desc').forEach(header => {
            header.addEventListener('click', function(e) {
                e.preventDefault();
                
                // Build the full URL with current page path
                const dataUrl = this.getAttribute('data-url');
                const currentPath = window.location.pathname;
                const fullUrl = currentPath + dataUrl;
                
                // Update URL in browser without reload
                window.history.pushState({}, '', fullUrl);
                
                // Show loading indicator
                const tbody = document.getElementById('voterTableBody');
                tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:40px; color:#6c757d;"><div style="display:inline-block; width:20px; height:20px; border:3px solid #f3f3f3; border-top:3px solid #667eea; border-radius:50%; animation:spin 1s linear infinite;"></div> Loading...</td></tr>';
                
                // Add spin animation
                if (!document.getElementById('spinner-style')) {
                    const style = document.createElement('style');
                    style.id = 'spinner-style';
                    style.textContent = '@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }';
                    document.head.appendChild(style);
                }
                
                // Fetch sorted data
                const separator = dataUrl.includes('?') ? '&' : '?';
                fetch(fullUrl + separator + 'ajax=1')
                    .then(response => {
                        if (!response.ok) {
                            throw new Error('Network response was not ok');
                        }
                        return response.json();
                    })
                    .then(data => {
                        // Update table headers
                        document.querySelectorAll('th').forEach((th, index) => {
                            th.className = data.headers[index].class;
                            th.setAttribute('data-url', data.headers[index].url);
                        });
                        
                        // Update table body
                        tbody.innerHTML = data.html;
                        
                        // Update stats
                        document.querySelector('.stats').innerHTML = data.stats;
                    })
                    .catch(error => {
                        console.error('Error:', error);
                        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:40px; color:#dc3545;">Error loading data. Please refresh the page.</td></tr>';
                    });
            });
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
    selected_party = request.args.get('party', 'ALL')
    sort_column = request.args.get('sort', 'name')
    sort_direction = request.args.get('dir', 'asc')
    show_all = request.args.get('limit') == 'all'
    
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Get status counts for dropdown (all voters)
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
    
    # Get status counts for pie chart (filtered by party if selected)
    if selected_party != 'ALL':
        cursor.execute(f"""
            SELECT 
                CASE 
                    WHEN status IS NULL OR status = '' THEN 'Outstanding'
                    ELSE status 
                END as status_display,
                COALESCE(status, '') as status_value,
                COUNT(*) as count 
            FROM fcabs2025 
            WHERE party = '{selected_party}'
            GROUP BY status 
            ORDER BY count DESC
        """)
    else:
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
    chart_statuses = [{'display': row['status_display'], 
                       'value': row['status_value'], 
                       'count': row['count']} 
                      for row in cursor.fetchall()]
    
    # Get party counts
    cursor.execute("""
        SELECT 
            party,
            COUNT(*) as count 
        FROM fcabs2025 
        GROUP BY party 
        ORDER BY count DESC
    """)
    parties = [{'party': row['party'], 
                'count': row['count']} 
               for row in cursor.fetchall()]
    
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
    where_clauses = []
    
    if selected_status != 'ALL':
        if selected_status == '' or selected_status == 'Outstanding':
            where_clauses.append("(status IS NULL OR status = '')")
        else:
            where_clauses.append(f"status = '{selected_status}'")
    
    if selected_party != 'ALL':
        where_clauses.append(f"party = '{selected_party}'")
    
    if where_clauses:
        voter_query += " WHERE " + " AND ".join(where_clauses)
    
    # Add ORDER BY clause based on sort parameters with secondary sort by name
    direction = 'DESC' if sort_direction == 'desc' else 'ASC'
    
    if sort_column == 'name':
        order_by = f"last_name {direction}, first_name {direction}"
    elif sort_column == 'party':
        order_by = f"party {direction}, last_name, first_name"
    elif sort_column == 'address':
        order_by = f"address_line_1 {direction}, last_name, first_name"
    elif sort_column == 'city':
        order_by = f"city {direction}, state {direction}, last_name, first_name"
    elif sort_column == 'precinct':
        order_by = f"precinct_name {direction}, last_name, first_name"
    elif sort_column == 'requested':
        order_by = f"date_requested {direction}, last_name, first_name"
    elif sort_column == 'returned':
        order_by = f"date_returned {direction}, last_name, first_name"
    elif sort_column == 'status':
        order_by = f"status {direction}, last_name, first_name"
    else:
        order_by = "last_name, first_name"
    
    voter_query += f" ORDER BY {order_by}"
    
    # Get total count before applying limit
    count_query = f"SELECT COUNT(*) as total FROM fcabs2025{where_clause}"
    cursor.execute(count_query)
    total_count_filtered = cursor.fetchone()['total']
    
    # Add LIMIT unless showing all
    if not show_all:
        voter_query += " LIMIT 1000"
    
    cursor.execute(voter_query)
    voters = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    # Handle AJAX requests
    if request.args.get('ajax') == '1':
        # Build table HTML
        table_html = ''
        for voter in voters:
            table_html += '<tr>'
            table_html += f'<td><strong>{voter["last_name"]}</strong>, {voter["first_name"]}'
            if voter['middle_name']:
                table_html += f' {voter["middle_name"][0]}.'
            table_html += '</td>'
            table_html += f'<td><span class="party-{voter["party"]}">{voter["party"]}</span></td>'
            table_html += f'<td>{voter["address_line_1"]}</td>'
            table_html += f'<td>{voter["city"]}, {voter["state"]} {voter["zip"]}</td>'
            table_html += f'<td style="font-size: 11px;">{voter["precinct_name"]}</td>'
            table_html += f'<td>{voter["date_requested"].strftime("%m/%d/%Y") if voter["date_requested"] else "-"}</td>'
            table_html += f'<td>{voter["date_returned"].strftime("%m/%d/%Y") if voter["date_returned"] else "-"}</td>'
            
            status = voter['status_display']
            if status == 'VAL':
                badge_class = 'badge badge-val'
            elif status == 'Outstanding':
                badge_class = 'badge badge-outstanding'
            else:
                badge_class = 'badge badge-problem'
            table_html += f'<td><span class="{badge_class}">{status}</span></td>'
            table_html += '</tr>'
        
        # Build headers info
        columns = [
            ('name', 'Name'),
            ('party', 'Party'),
            ('address', 'Address'),
            ('city', 'City'),
            ('precinct', 'Precinct'),
            ('requested', 'Requested'),
            ('returned', 'Returned'),
            ('status', 'Status')
        ]
        
        headers = []
        for col, label in columns:
            params = {}
            if selected_status != 'ALL':
                params['status'] = selected_status
            if selected_party != 'ALL':
                params['party'] = selected_party
            params['sort'] = col
            
            if sort_column == col:
                params['dir'] = 'desc' if sort_direction == 'asc' else 'asc'
                sort_class = 'sort-asc' if sort_direction == 'asc' else 'sort-desc'
            else:
                params['dir'] = 'asc'
                sort_class = 'sortable'
            
            query_string = '&'.join([f'{k}={v}' for k, v in params.items()])
            headers.append({
                'class': sort_class,
                'url': f'?{query_string}'
            })
        
        display_count = total_count_filtered
        showing_limit = ""
        show_all_button = ""
        
        if not show_all and display_count >= 1000:
            showing_limit = " (showing first 1,000)"
            # Build show all URL
            params = {}
            if selected_status != 'ALL':
                params['status'] = selected_status
            if selected_party != 'ALL':
                params['party'] = selected_party
            if sort_column != 'name':
                params['sort'] = sort_column
            if sort_direction != 'asc':
                params['dir'] = sort_direction
            params['limit'] = 'all'
            show_all_url = '?' + urlencode(params)
            show_all_button = f' <button onclick="window.location.href=\'{show_all_url}\'" style="padding:5px 12px; background:#667eea; color:white; border:none; border-radius:4px; cursor:pointer; font-size:13px; margin-left:10px;">Show all</button>'
        stats_html = f'{display_count:,} voters{showing_limit}{show_all_button}'
        
        return jsonify({
            'html': table_html,
            'headers': headers,
            'stats': stats_html
        })
    
    # Calculate showing_limit and show_all_button for initial page load
    display_count_main = total_count_filtered
    showing_limit_main = ""
    show_all_button_main = ""
    
    if not show_all and display_count_main >= 1000:
        showing_limit_main = " (showing first 1,000)"
        # Build show all URL
        params = {}
        if selected_status != 'ALL':
            params['status'] = selected_status
        if selected_party != 'ALL':
            params['party'] = selected_party
        if sort_column != 'name':
            params['sort'] = sort_column
        if sort_direction != 'asc':
            params['dir'] = sort_direction
        params['limit'] = 'all'
        show_all_url = '?' + urlencode(params)
        show_all_button_main = f' <button onclick="window.location.href=\'{show_all_url}\'" style="padding:5px 12px; background:#667eea; color:white; border:none; border-radius:4px; cursor:pointer; font-size:13px; margin-left:10px;">Show all</button>'
    
    return render_template_string(
        HTML_TEMPLATE,
        voters=voters,
        statuses=statuses,
        chart_statuses=chart_statuses,
        parties=parties,
        total_count=total_count,
        selected_status=selected_status,
        selected_party=selected_party,
        sort_column=sort_column,
        sort_direction=sort_direction,
        showing_limit=showing_limit_main,
        show_all_button=show_all_button_main,
        display_count=display_count_main
    )

if __name__ == '__main__':
    print("Starting Franklin County Voter Viewer...")
    print("Access the application at: http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)

