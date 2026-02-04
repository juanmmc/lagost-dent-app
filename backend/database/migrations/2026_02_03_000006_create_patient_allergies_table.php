<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('patient_allergies', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('patient_id')->constrained('patients')->restrictOnDelete();
            $table->string('name');
            $table->string('severity')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index('patient_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('patient_allergies');
    }
};
