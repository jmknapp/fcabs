<?php
// Franklin County Absentee Ballot Voter Viewer

// Load environment variables from .env file
function loadEnv($path) {
    if (!file_exists($path)) {
        die("Error: .env file not found. Please copy .env.example to .env and configure your database credentials.");
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        // Skip comments and empty lines
        if (strpos(trim($line), '#') === 0 || trim($line) === '') {
            continue;
        }
        
        // Parse KEY=VALUE
        list($name, $value) = explode('=', $line, 2);
        $name = trim($name);
        $value = trim($value);
        
        // Set as environment variable if not already set
        if (!getenv($name)) {
            putenv("$name=$value");
        }
    }
}

// Load .env file
loadEnv(__DIR__ . '/.env');

// Database connection settings from environment variables
$db_host = getenv('DB_HOST') ?: 'localhost';
$db_user = getenv('DB_USER');
$db_pass = getenv('DB_PASS');
$db_name = getenv('DB_NAME');

// Get selected filters from dropdown
$selected_status = isset($_GET['status']) ? $_GET['status'] : 'ALL';
$selected_party = isset($_GET['party']) ? $_GET['party'] : 'ALL';
$sort_column = isset($_GET['sort']) ? $_GET['sort'] : 'name';
$sort_direction = isset($_GET['dir']) && $_GET['dir'] === 'desc' ? 'desc' : 'asc';
$show_all = isset($_GET['limit']) && $_GET['limit'] === 'all';

// Connect to database
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get status counts for dropdown (all voters)
$status_query = "
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
";
$status_result = $conn->query($status_query);
$statuses = [];
$total_count = 0;
while ($row = $status_result->fetch_assoc()) {
    $statuses[] = $row;
    $total_count += $row['count'];
}

// Get status counts for pie chart (filtered by party if selected)
$chart_query = "
    SELECT 
        CASE 
            WHEN status IS NULL OR status = '' THEN 'Outstanding'
            ELSE status 
        END as status_display,
        COALESCE(status, '') as status_value,
        COUNT(*) as count 
    FROM fcabs2025
";
if ($selected_party !== 'ALL') {
    $chart_query .= " WHERE party = '" . $conn->real_escape_string($selected_party) . "'";
}
$chart_query .= " GROUP BY status ORDER BY count DESC";

$chart_result = $conn->query($chart_query);
$chart_statuses = [];
while ($row = $chart_result->fetch_assoc()) {
    $chart_statuses[] = $row;
}

// Get party counts for dropdown
$party_query = "
    SELECT 
        party,
        COUNT(*) as count 
    FROM fcabs2025 
    GROUP BY party 
    ORDER BY count DESC
";
$party_result = $conn->query($party_query);
$parties = [];
while ($row = $party_result->fetch_assoc()) {
    $parties[] = $row;
}

// Build voter query based on selected status
$voter_query = "
    SELECT 
        local_id,
        first_name,
        middle_name,
        last_name,
        party,
        city_or_village,
        precinct_name,
        address_line_1,
        city,
        state,
        zip,
        date_requested,
        date_returned,
        CASE 
            WHEN status IS NULL OR status = '' THEN 'Outstanding'
            ELSE status 
        END as status_display,
        ballot_style
    FROM fcabs2025
";

// Add WHERE clause based on selections
$where_clauses = [];

if ($selected_status !== 'ALL') {
    if ($selected_status === 'Outstanding') {
        $where_clauses[] = "(status IS NULL OR status = '')";
    } else {
        $where_clauses[] = "status = '" . $conn->real_escape_string($selected_status) . "'";
    }
}

if ($selected_party !== 'ALL') {
    $where_clauses[] = "party = '" . $conn->real_escape_string($selected_party) . "'";
}

if (count($where_clauses) > 0) {
    $voter_query .= " WHERE " . implode(' AND ', $where_clauses);
}

// Add ORDER BY clause based on sort parameters
$order_by = "";
switch($sort_column) {
    case 'name':
        $order_by = "last_name, first_name";
        break;
    case 'party':
        $order_by = "party " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    case 'address':
        $order_by = "address_line_1 " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    case 'city':
        $order_by = "city " . strtoupper($sort_direction) . ", state " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    case 'precinct':
        $order_by = "precinct_name " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    case 'requested':
        $order_by = "date_requested " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    case 'returned':
        $order_by = "date_returned " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    case 'status':
        $order_by = "status " . strtoupper($sort_direction) . ", last_name, first_name";
        break;
    default:
        $order_by = "last_name, first_name";
}

// For name column, apply direction to the order by
if ($sort_column === 'name') {
    $voter_query .= " ORDER BY " . $order_by . " " . strtoupper($sort_direction);
} else {
    $voter_query .= " ORDER BY " . $order_by;
}

// Get total count before applying limit
$count_query = "SELECT COUNT(*) as total FROM fcabs2025" . $where_clause;
$count_result = $conn->query($count_query);
$total_count_filtered = $count_result->fetch_assoc()['total'];

// Add LIMIT unless showing all
if (!$show_all) {
    $voter_query .= " LIMIT 1000";
}

$voter_result = $conn->query($voter_query);
$voters = [];
while ($row = $voter_result->fetch_assoc()) {
    $voters[] = $row;
}

$display_count = $total_count_filtered;
$showing_limit = "";
$show_all_button = "";

if (!$show_all && $display_count >= 1000) {
    $showing_limit = " (showing first 1,000)";
    // Build show all URL
    $params = [];
    if ($selected_status !== 'ALL') $params['status'] = $selected_status;
    if ($selected_party !== 'ALL') $params['party'] = $selected_party;
    if ($sort_column !== 'name') $params['sort'] = $sort_column;
    if ($sort_direction !== 'asc') $params['dir'] = $sort_direction;
    $params['limit'] = 'all';
    $show_all_url = '?' . http_build_query($params);
    $show_all_button = ' <button onclick="window.location.href=\'' . $show_all_url . '\'" style="padding:5px 12px; background:#667eea; color:white; border:none; border-radius:4px; cursor:pointer; font-size:13px; margin-left:10px;">Show all</button>';
}

// Handle AJAX requests
if (isset($_GET['ajax']) && $_GET['ajax'] == '1') {
    header('Content-Type: application/json');
    
    // Build table HTML
    $table_html = '';
    foreach ($voters as $voter) {
        $table_html .= '<tr>';
        $table_html .= '<td><strong>' . htmlspecialchars($voter['last_name']) . '</strong>, ' . htmlspecialchars($voter['first_name']);
        if ($voter['middle_name']) {
            $table_html .= ' ' . htmlspecialchars(substr($voter['middle_name'], 0, 1)) . '.';
        }
        $table_html .= '</td>';
        $table_html .= '<td><span class="party-' . htmlspecialchars($voter['party']) . '">' . htmlspecialchars($voter['party']) . '</span></td>';
        $table_html .= '<td>' . htmlspecialchars($voter['address_line_1']) . '</td>';
        $table_html .= '<td>' . htmlspecialchars($voter['city']) . ', ' . htmlspecialchars($voter['state']) . ' ' . htmlspecialchars($voter['zip']) . '</td>';
        $table_html .= '<td style="font-size: 11px;">' . htmlspecialchars($voter['precinct_name']) . '</td>';
        $table_html .= '<td>' . ($voter['date_requested'] ? date('m/d/Y', strtotime($voter['date_requested'])) : '-') . '</td>';
        $table_html .= '<td>' . ($voter['date_returned'] ? date('m/d/Y', strtotime($voter['date_returned'])) : '-') . '</td>';
        $status = $voter['status_display'];
        $badge_class = 'badge ';
        if ($status === 'VAL') {
            $badge_class .= 'badge-val';
        } elseif ($status === 'Outstanding') {
            $badge_class .= 'badge-outstanding';
        } else {
            $badge_class .= 'badge-problem';
        }
        $table_html .= '<td><span class="' . $badge_class . '">' . htmlspecialchars($status) . '</span></td>';
        $table_html .= '</tr>';
    }
    
    // Build headers info
    $columns = [
        'name' => 'Name',
        'party' => 'Party',
        'address' => 'Address',
        'city' => 'City',
        'precinct' => 'Precinct',
        'requested' => 'Requested',
        'returned' => 'Returned',
        'status' => 'Status'
    ];
    
    $headers = [];
    foreach ($columns as $col => $label) {
        $params = [];
        if ($selected_status !== 'ALL') $params['status'] = $selected_status;
        if ($selected_party !== 'ALL') $params['party'] = $selected_party;
        $params['sort'] = $col;
        
        if ($sort_column === $col) {
            $params['dir'] = $sort_direction === 'asc' ? 'desc' : 'asc';
            $sort_class = $sort_direction === 'asc' ? 'sort-asc' : 'sort-desc';
        } else {
            $params['dir'] = 'asc';
            $sort_class = 'sortable';
        }
        
        $headers[] = [
            'class' => $sort_class,
            'url' => '?' . http_build_query($params)
        ];
    }
    
    $stats_html = number_format($display_count) . ' voters' . $showing_limit . $show_all_button;
    
    echo json_encode([
        'html' => $table_html,
        'headers' => $headers,
        'stats' => $stats_html
    ]);
    exit;
}
?>
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
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
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
        
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 14px;
        }
        
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
            white-space: nowrap;
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
            color: #212529;
        }
        
        tr:hover {
            background: #f8f9fa;
        }
        
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .badge-val {
            background: #d4edda;
            color: #155724;
        }
        
        .badge-outstanding {
            background: #fff3cd;
            color: #856404;
        }
        
        .badge-problem {
            background: #f8d7da;
            color: #721c24;
        }
        
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
        
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #6c757d;
        }
        
        .empty-state svg {
            width: 64px;
            height: 64px;
            margin-bottom: 20px;
            opacity: 0.3;
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
                    📅 Data as of: <strong>November 6, 2025</strong>
                </p>
            </div>
        </div>
        
        <div class="controls">
            <div class="filter-group">
                <label for="status-filter">Filter by Status:</label>
                <select id="status-filter" name="status" onchange="applyFilters()">
                    <option value="ALL" <?php echo $selected_status === 'ALL' ? 'selected' : ''; ?>>
                        All Statuses (<?php echo number_format($total_count); ?>)
                    </option>
                    <?php foreach ($statuses as $status): ?>
                        <option value="<?php echo htmlspecialchars($status['status_value']); ?>" 
                                <?php echo $selected_status === $status['status_value'] || 
                                          ($selected_status === 'Outstanding' && $status['status_display'] === 'Outstanding') 
                                          ? 'selected' : ''; ?>>
                            <?php echo htmlspecialchars($status['status_display']); ?> 
                            (<?php echo number_format($status['count']); ?>)
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            
            <div class="filter-group">
                <label for="party-filter">Filter by Party:</label>
                <select id="party-filter" name="party" onchange="applyFilters()">
                    <option value="ALL" <?php echo $selected_party === 'ALL' ? 'selected' : ''; ?>>
                        All Parties (<?php echo number_format($total_count); ?>)
                    </option>
                    <?php foreach ($parties as $party): ?>
                        <option value="<?php echo htmlspecialchars($party['party']); ?>" 
                                <?php echo $selected_party === $party['party'] ? 'selected' : ''; ?>>
                            <?php echo htmlspecialchars($party['party']); ?> 
                            (<?php echo number_format($party['count']); ?>)
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
        </div>
        
        <div class="chart-section">
            <div class="chart-title">
                Ballot Status Distribution
                <?php if ($selected_party !== 'ALL'): ?>
                    <span style="font-weight: normal; font-size: 16px; color: #6c757d;">
                        (Party: <?php echo htmlspecialchars($selected_party); ?>)
                    </span>
                <?php endif; ?>
            </div>
            <div class="chart-container">
                <canvas id="statusChart"></canvas>
            </div>
        </div>
        
        <div class="stats">
            <?php echo number_format($display_count); ?> voters<?php echo $showing_limit; ?><?php echo $show_all_button; ?>
        </div>
        
        <div class="table-container">
            <?php if (count($voters) > 0): ?>
                <table id="voterTable">
                    <thead>
                        <tr>
                            <?php
                            $columns = [
                                'name' => 'Name',
                                'party' => 'Party',
                                'address' => 'Address',
                                'city' => 'City',
                                'precinct' => 'Precinct',
                                'requested' => 'Requested',
                                'returned' => 'Returned',
                                'status' => 'Status'
                            ];
                            
                            foreach ($columns as $col => $label) {
                                $params = [];
                                if ($selected_status !== 'ALL') $params['status'] = $selected_status;
                                if ($selected_party !== 'ALL') $params['party'] = $selected_party;
                                $params['sort'] = $col;
                                
                                // Toggle direction
                                if ($sort_column === $col) {
                                    $params['dir'] = $sort_direction === 'asc' ? 'desc' : 'asc';
                                    $sort_class = $sort_direction === 'asc' ? 'sort-asc' : 'sort-desc';
                                } else {
                                    $params['dir'] = 'asc';
                                    $sort_class = 'sortable';
                                }
                                
                                $url = '?' . http_build_query($params);
                                echo "<th class='$sort_class' data-url='$url'>$label</th>";
                            }
                            ?>
                        </tr>
                    </thead>
                    <tbody id="voterTableBody">
                        <?php foreach ($voters as $voter): ?>
                            <tr>
                                <td>
                                    <strong><?php echo htmlspecialchars($voter['last_name']); ?></strong>, 
                                    <?php echo htmlspecialchars($voter['first_name']); ?>
                                    <?php if ($voter['middle_name']): ?>
                                        <?php echo htmlspecialchars(substr($voter['middle_name'], 0, 1)); ?>.
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <span class="party-<?php echo htmlspecialchars($voter['party']); ?>">
                                        <?php echo htmlspecialchars($voter['party']); ?>
                                    </span>
                                </td>
                                <td><?php echo htmlspecialchars($voter['address_line_1']); ?></td>
                                <td><?php echo htmlspecialchars($voter['city']); ?>, <?php echo htmlspecialchars($voter['state']); ?> <?php echo htmlspecialchars($voter['zip']); ?></td>
                                <td style="font-size: 11px;"><?php echo htmlspecialchars($voter['precinct_name']); ?></td>
                                <td><?php echo $voter['date_requested'] ? date('m/d/Y', strtotime($voter['date_requested'])) : '-'; ?></td>
                                <td><?php echo $voter['date_returned'] ? date('m/d/Y', strtotime($voter['date_returned'])) : '-'; ?></td>
                                <td>
                                    <?php 
                                    $status = $voter['status_display'];
                                    $badge_class = 'badge ';
                                    if ($status === 'VAL') {
                                        $badge_class .= 'badge-val';
                                    } elseif ($status === 'Outstanding') {
                                        $badge_class .= 'badge-outstanding';
                                    } else {
                                        $badge_class .= 'badge-problem';
                                    }
                                    ?>
                                    <span class="<?php echo $badge_class; ?>"><?php echo htmlspecialchars($status); ?></span>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php else: ?>
                <div class="empty-state">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <h3>No voters found</h3>
                    <p>Try selecting a different status filter</p>
                </div>
            <?php endif; ?>
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
        const statusData = <?php echo json_encode($chart_statuses); ?>;
        
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
        const labels = statusData.map(s => s.status_display);
        const values = statusData.map(s => parseInt(s.count));  // Ensure numbers
        const colors = statusData.map(s => statusColors[s.status_display] || '#6c757d');
        
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
<?php
$conn->close();
?>

