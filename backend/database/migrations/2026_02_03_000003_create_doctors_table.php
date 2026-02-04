<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('doctors', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('person_id')->constrained('people')->restrictOnDelete();
            $table->string('password_hash');
            $table->boolean('active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->unique('person_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('doctors');
    }
};
