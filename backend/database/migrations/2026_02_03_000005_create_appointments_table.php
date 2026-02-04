<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('appointments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('scheduled_by_person_id')->constrained('people')->restrictOnDelete();
            $table->foreignUuid('patient_id')->constrained('patients')->restrictOnDelete();
            $table->foreignUuid('doctor_id')->constrained('doctors')->restrictOnDelete();
            $table->dateTime('scheduled_at');
            $table->tinyInteger('status');
            $table->text('diagnosis_text')->nullable();
            $table->foreignUuid('deposit_slip_attachment_id')->nullable()->constrained('attachments')->nullOnDelete();
            $table->foreignUuid('recipe_attachment_id')->nullable()->constrained('attachments')->nullOnDelete();
            $table->dateTime('confirmed_at')->nullable();
            $table->dateTime('attended_at')->nullable();
            $table->dateTime('absent_at')->nullable();
            $table->dateTime('rejected_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique('scheduled_at');
            $table->index(['doctor_id', 'scheduled_at']);
            $table->index(['patient_id', 'scheduled_at']);
            $table->index('status');
            $table->index('scheduled_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('appointments');
    }
};
