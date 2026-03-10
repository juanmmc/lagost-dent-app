<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attachment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Http\JsonResponse;

class AttachmentController extends Controller
{
    public function upload(Request $request): JsonResponse
    {
        $request->validate([
            'file' => ['required','file','max:5120'],
            'type' => ['required','string'],
        ]);

        $file = $request->file('file');
        $disk = 'public';
        $path = $file->store('attachments', $disk);

        $attachment = Attachment::create([
            'path' => $path,
            'type' => $request->input('type'),
            'mime' => $file->getClientMimeType(),
            'size' => $file->getSize(),
            'disk' => $disk,
        ]);

        return response()->json([
            'id' => $attachment->id,
            'path' => $attachment->path,
            'url' => Storage::disk($disk)->url($attachment->path),
        ], 201);
    }
}
