<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\Person;
use App\Models\Patient;
use Illuminate\Support\Carbon;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;

class AttachmentUploadTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_can_upload_attachment_returns_id_and_path(): void
    {
        Storage::fake('local');

        $person = Person::create(['phone' => '960000010', 'name' => 'Paciente Upload']);
        Patient::create(['person_id' => $person->id, 'birthdate' => '1997-08-08']);

        Sanctum::actingAs($person, ['patient']);

        $file = UploadedFile::fake()->image('deposit.jpg', 600, 600);

        $response = $this->postJson('/api/attachments', [
            'file' => $file,
            'type' => 'deposit_slip',
        ]);

        $response->assertStatus(201);
        $data = $response->json();
        $this->assertArrayHasKey('id', $data);
        $this->assertArrayHasKey('path', $data);
        Storage::disk('local')->assertExists($data['path']);
    }
}
