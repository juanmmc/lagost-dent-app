<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use App\Models\Person;
use App\Models\Patient;
use App\Models\Doctor;
use App\Models\PatientRelation;
use App\Models\Attachment;
use App\Models\Appointment;
use App\Enums\AppointmentStatus;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Doctor
        $doctorPerson = Person::create([
            'phone' => '999000002',
            'name' => 'Dr. Demo',
        ]);
        $doctor = Doctor::create([
            'person_id' => $doctorPerson->id,
            'password_hash' => Hash::make('secret'),
            'active' => true,
        ]);

        // Titular patient
        $titularPerson = Person::create([
            'phone' => '999000001',
            'name' => 'Paciente Titular',
        ]);
        $titular = Patient::create([
            'person_id' => $titularPerson->id,
            'birthdate' => '1990-01-01',
        ]);

        // Associated patient
        $assocPerson = Person::create([
            'phone' => '999000003',
            'name' => 'Paciente Asociado',
        ]);
        $associated = Patient::create([
            'person_id' => $assocPerson->id,
            'birthdate' => '2010-05-10',
        ]);

        // Relation titular -> associated
        PatientRelation::create([
            'titular_patient_id' => $titular->id,
            'associated_patient_id' => $associated->id,
            'relation_type' => 'family',
        ]);

        // Deposit slip attachment
        $deposit = Attachment::create([
            'path' => 'attachments/demo-deposit.jpg',
            'type' => 'deposit_slip',
            'mime' => 'image/jpeg',
            'size' => 12345,
            'disk' => 'local',
        ]);

        // Pending appointment for titular
        Appointment::create([
            'scheduled_by_person_id' => $titularPerson->id,
            'patient_id' => $titular->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => now()->addDays(7)->setTime(10, 0, 0),
            'status' => AppointmentStatus::PendingConfirmation,
            'deposit_slip_attachment_id' => $deposit->id,
        ]);
    }
}
