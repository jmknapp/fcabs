<?php
// Franklin County Absentee Ballot Voter Viewer
// Database connection settings
$db_host = 'localhost';
$db_user = 'root';
$db_pass = 'R_250108_z';
$db_name = 'ohsosvoterfiles';

// Get selected status from dropdown
$selected_status = isset($_GET['status']) ? $_GET['status'] : 'ALL';

// Connect to database
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Get status counts for dropdown
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

// Add WHERE clause based on selection
if ($selected_status !== 'ALL') {
    if ($selected_status === 'Outstanding') {
        $voter_query .= " WHERE (status IS NULL OR status = '')";
    } else {
        $voter_query .= " WHERE status = '" . $conn->real_escape_string($selected_status) . "'";
    }
}

$voter_query .= " ORDER BY last_name, first_name LIMIT 1000";

$voter_result = $conn->query($voter_query);
$voters = [];
while ($row = $voter_result->fetch_assoc()) {
    $voters[] = $row;
}

$display_count = count($voters);
$showing_limit = $display_count >= 1000 ? " (showing first 1000)" : "";
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
                    📅 Data as of: <strong>November 4, 2025</strong>
                </p>
            </div>
        </div>
        
        <div class="controls">
            <label for="status-filter">Filter by Status:</label>
            <select id="status-filter" name="status" onchange="filterStatus()">
                <option value="ALL" <?php echo $selected_status === 'ALL' ? 'selected' : ''; ?>>
                    All Voters (<?php echo number_format($total_count); ?>)
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
        
        <div class="chart-section">
            <div class="chart-title">Ballot Status Distribution</div>
            <div class="chart-container">
                <canvas id="statusChart"></canvas>
            </div>
        </div>
        
        <div class="stats">
            <strong>Showing:</strong> <?php echo number_format($display_count); ?> voters<?php echo $showing_limit; ?>
        </div>
        
        <div class="table-container">
            <?php if (count($voters) > 0): ?>
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
        function filterStatus() {
            const select = document.getElementById('status-filter');
            const status = select.value;
            window.location.href = '?status=' + encodeURIComponent(status);
        }
        
        // Status Chart Data
        const statusData = <?php echo json_encode($statuses); ?>;
        
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
    </script>
</body>
</html>
<?php
$conn->close();
?>

