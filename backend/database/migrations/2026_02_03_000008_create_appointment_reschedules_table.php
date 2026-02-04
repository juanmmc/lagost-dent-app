<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('appointment_reschedules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('appointment_id')->constrained('appointments')->restrictOnDelete();
            $table->foreignUuid('actor_person_id')->constrained('people')->restrictOnDelete();
            $table->dateTime('previous_scheduled_at');
            $table->dateTime('new_scheduled_at');
            $table->text('reason')->nullable();
            $table->timestamps();
            $table->index('appointment_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('appointment_reschedules');
    }
};
