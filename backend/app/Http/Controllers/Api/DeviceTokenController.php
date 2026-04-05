<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DeviceTokenController extends Controller
{
    /**
     * Register or refresh the FCM device token for the authenticated user.
     * Idempotent: if the token already exists it updates last_seen_at and marks it active.
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token'    => ['required', 'string', 'max:4096'],
            'platform' => ['sometimes', 'string', 'in:android,ios'],
        ]);

        $personId = Auth::id();

        DeviceToken::updateOrCreate(
            ['token' => $validated['token']],
            [
                'person_id'    => $personId,
                'platform'     => $validated['platform'] ?? 'android',
                'is_active'    => true,
                'last_seen_at' => now(),
            ]
        );

        return response()->json(['message' => 'Token registered'], 200);
    }

    /**
     * Deactivate a token on logout so the user stops receiving notifications.
     */
    public function deactivate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:4096'],
        ]);

        DeviceToken::where('token', $validated['token'])
            ->where('person_id', Auth::id())
            ->update(['is_active' => false]);

        return response()->json(['message' => 'Token deactivated'], 200);
    }
}
