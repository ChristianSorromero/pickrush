<?php
namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class HubSeeder extends Seeder
{
    public function run(): void
    {
        $hubs = [
            ['id' => 'qc',  'name' => 'Quezon City Hub', 'province' => 'Metro Manila (NCR)'],
            ['id' => 'mnl', 'name' => 'Manila Hub',      'province' => 'Metro Manila (NCR)'],
            ['id' => 'mkt', 'name' => 'Makati Hub',      'province' => 'Metro Manila (NCR)'],
            ['id' => 'clb', 'name' => 'Calamba Hub',     'province' => 'Laguna'],
            ['id' => 'sta', 'name' => 'Santa Rosa Hub',  'province' => 'Laguna'],
            ['id' => 'bco', 'name' => 'Bacoor Hub',      'province' => 'Cavite'],
            ['id' => 'dsm', 'name' => 'Dasmariñas Hub', 'province' => 'Cavite'],
        ];
        foreach ($hubs as $hub) {
            DB::table('hubs')->updateOrInsert(['id' => $hub['id']], array_merge($hub, ['is_active' => true]));
        }
    }
}
