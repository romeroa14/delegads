<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureApiRequest
{
    /**
     * Force the request to be treated as JSON so the framework returns
     * 401 JSON envelopes (rather than HTML redirects) when an API
     * call lacks valid Sanctum credentials.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
