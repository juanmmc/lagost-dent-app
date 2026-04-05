<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PushNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Internal endpoint for manually testing FCM push delivery.
 * Protect with a middleware or remove before production.
 */
class PushTestController extends Controller
{
    public function __construct(private readonly PushNotificationService $push) {}

    public function send(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string'],
            'title' => ['required', 'string', 'max:255'],
            'body'  => ['required', 'string', 'max:1024'],
            'data'  => ['sometimes', 'array'],
        ]);

        $this->push->sendToToken(
            $validated['token'],
            $validated['title'],
            $validated['body'],
            $validated['data'] ?? [],
        );

        return response()->json(['message' => 'Notification sent successfully']);
    }
}
