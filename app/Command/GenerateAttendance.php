<?php
 
namespace App\Commands;
 
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;
use Config\Database;
 
class GenerateAttendance extends BaseCommand
{
    protected $group       = 'HRMS';
    protected $name        = 'attendance:generate';
    protected $description = 'Generate daily attendance';
 
    public function run(array $params)
    {
        // India timezone
        date_default_timezone_set('Asia/Kolkata');
 
        $date = date('Y-m-d');
 
        $db = Database::connect();
 
        $db->query(
            "CALL generate_attendance(?)",
            [$date]
        );
 
        CLI::write(
            "Attendance generated successfully for: " . $date,
            'green'
        );
    }
}