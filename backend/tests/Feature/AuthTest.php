<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\Person;
use App\Models\Patient;
use App\Models\Doctor;
use Illuminate\Support\Facades\Hash;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_login_returns_token_and_ids(): void
    {
        $person = Person::create(['phone' => '900000001', 'name' => 'Paciente Test']);
        Patient::create(['person_id' => $person->id, 'birthdate' => '1990-01-01']);

        $response = $this->postJson('/api/auth/patients/validate', [
            'phone' => '900000001',
            'birthdate' => '1990-01-01',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['token', 'patient_id', 'person_id']);
    }

    public function test_doctor_login_returns_token_and_ids(): void
    {
        $person = Person::create(['phone' => '900000002', 'name' => 'Doctor Test']);
        Doctor::create([
            'person_id' => $person->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        $response = $this->postJson('/api/auth/doctors/validate', [
            'phone' => '900000002',
            'password' => 'secret',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['token', 'doctor_id', 'person_id']);
    }
}
