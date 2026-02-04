<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('patient_relations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('titular_patient_id')->constrained('patients')->restrictOnDelete();
            $table->foreignUuid('associated_patient_id')->constrained('patients')->restrictOnDelete();
            $table->string('relation_type')->nullable();
            $table->timestamps();
            $table->unique(['titular_patient_id', 'associated_patient_id']);
            // Enforce that an associated patient can have only one titular
            $table->unique('associated_patient_id');
            $table->index('titular_patient_id');
            $table->index('associated_patient_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('patient_relations');
    }
};
