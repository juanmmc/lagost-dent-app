<?php

declare(strict_types=1);

return [
    'default' => env('FIREBASE_PROJECT', 'app'),

    'projects' => [
        'app' => [
            /*
             * Credentials resolution (first match wins):
             *   1. FIREBASE_CREDENTIALS_FILE  → filename only, resolved under storage/app/private/
             *      e.g.  FIREBASE_CREDENTIALS_FILE=my-app-firebase-adminsdk-xxxxx.json
             *   2. FIREBASE_CREDENTIALS        → full absolute path (set automatically by this project)
             *   3. GOOGLE_APPLICATION_CREDENTIALS → Google ADC standard variable
             */
            'credentials' => env('FIREBASE_CREDENTIALS_FILE')
                ? storage_path('app/private/' . env('FIREBASE_CREDENTIALS_FILE'))
                : env('FIREBASE_CREDENTIALS', env('GOOGLE_APPLICATION_CREDENTIALS')),

            'auth' => [
                'tenant_id' => env('FIREBASE_AUTH_TENANT_ID'),
            ],

            'firestore' => [
                // 'database' => env('FIREBASE_FIRESTORE_DATABASE'),
            ],

            'database' => [
                'url' => env('FIREBASE_DATABASE_URL'),
            ],

            'dynamic_links' => [
                'default_domain' => env('FIREBASE_DYNAMIC_LINKS_DEFAULT_DOMAIN'),
            ],

            'storage' => [
                'default_bucket' => env('FIREBASE_STORAGE_DEFAULT_BUCKET'),
            ],

            'cache_store' => env('FIREBASE_CACHE_STORE', 'file'),

            'logging' => [
                'http_log_channel'       => env('FIREBASE_HTTP_LOG_CHANNEL'),
                'http_debug_log_channel' => env('FIREBASE_HTTP_DEBUG_LOG_CHANNEL'),
            ],

            'http_client_options' => [
                'proxy'   => env('FIREBASE_HTTP_CLIENT_OPTIONS_PROXY'),
                'timeout' => env('FIREBASE_HTTP_CLIENT_OPTIONS_TIMEOUT'),
                'guzzle_middlewares' => [],
            ],
        ],
    ],
];
