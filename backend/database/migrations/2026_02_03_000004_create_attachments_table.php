<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('attachments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('path');
            $table->string('type');
            $table->string('mime')->nullable();
            $table->unsignedBigInteger('size')->nullable();
            $table->string('disk')->default('private');
            $table->timestamps();
            $table->index('type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attachments');
    }
};
