<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('rider_documents', function (Blueprint $table) {
            $table->id();
            $table->uuid('rider_id');
            $table->foreign('rider_id')->references('id')->on('riders')->cascadeOnDelete();
            $table->enum('doc_type', ['license_front','license_back','orcr']);
            $table->string('storage_path');
            $table->string('mime_type');
            $table->timestamp('uploaded_at')->useCurrent();
        });
    }
    public function down(): void { Schema::dropIfExists('rider_documents'); }
};
