<?php

use App\Http\Controllers\Api\EmailOtpController;
use App\Http\Controllers\Api\HubController;
use App\Http\Controllers\Api\RiderRegistrationController;
use Illuminate\Support\Facades\Route;

Route::get('/hubs', [HubController::class, 'index'])->name('hubs.index');

Route::prefix('auth')->name('auth.')->group(function (): void {
    Route::post('/email-otp/send', [EmailOtpController::class, 'send'])
        ->middleware('throttle:5,1')
        ->name('email-otp.send');
    Route::post('/email-otp/verify', [EmailOtpController::class, 'verify'])
        ->middleware('throttle:10,1')
        ->name('email-otp.verify');
});

Route::post('/riders/register', RiderRegistrationController::class)
    ->middleware('throttle:5,1')
    ->name('riders.register');
