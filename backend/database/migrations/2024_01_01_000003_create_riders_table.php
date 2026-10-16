<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('riders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('first_name');
            $table->string('last_name');
            $table->date('birth_date');
            $table->string('mobile', 10)->unique();
            $table->string('email')->unique();
            $table->string('password_hash');
            $table->string('province_code');
            $table->string('province_name');
            $table->string('city_code');
            $table->string('city_name');
            $table->string('barangay_code');
            $table->string('barangay_name');
            $table->text('street');
            $table->string('hub_id')->nullable();
            $table->foreign('hub_id')->references('id')->on('hubs')->nullOnDelete();
            $table->enum('vehicle_type', ['motorcycle','car','tricycle','bicycle_other']);
            $table->string('vehicle_model');
            $table->string('plate_number')->nullable();
            $table->enum('status', ['pending_review','approved','rejected'])->default('pending_review');
            $table->text('reject_reason')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('reviewed_by')->nullable();
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('riders'); }
};
