<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('people', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('phone')->unique();
            $table->string('name');
            $table->timestamps();
            $table->softDeletes();
            $table->index('name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('people');
    }
};
