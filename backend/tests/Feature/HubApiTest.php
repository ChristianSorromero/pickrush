<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HubApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_active_hubs_are_returned_in_the_mobile_api_shape(): void
    {
        $this->seed();

        $response = $this->getJson('/api/hubs');

        $response->assertOk()
            ->assertJsonCount(7)
            ->assertJsonStructure([
                ['id', 'name', 'province'],
            ]);
    }
}
