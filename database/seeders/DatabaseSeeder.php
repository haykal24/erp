<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Webkul\Partner\Database\Seeders\DatabaseSeeder as PartnerDatabaseSeeder;
use Webkul\Security\Database\Seeders\DatabaseSeeder as SecurityDatabaseSeeder;
use Webkul\Support\Database\Seeders\DatabaseSeeder as SupportDatabaseSeeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            SecurityDatabaseSeeder::class,
            SupportDatabaseSeeder::class,
            PartnerDatabaseSeeder::class, // Run before ShieldSeeder to ensure Industry exists
            ShieldSeeder::class,
        ]);
    }
}