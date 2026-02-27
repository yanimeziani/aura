import { NextResponse } from 'next/server';
import { dispatchComms } from '@/lib/comms';
import { isCommsTestTokenValid } from '@/lib/comms/config';
import { CommsDispatchRequest } from '@/lib/comms/types';

export const runtime = 'nodejs';

function readAuthToken(request: Request): string | null {
  const direct =
    request.headers.get('comms-test-token') ??
    request.headers.get('x-comms-test-token') ??
    request.headers.get('COMMS_TEST_TOKEN');

  if (direct) {
    return direct;
  }

  const authHeader = request.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }

  return authHeader.slice('Bearer '.length).trim();
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export async function POST(request: Request) {
  const token = readAuthToken(request);
  if (!isCommsTestTokenValid(token)) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  if (!isObject(payload) || (payload.channel !== 'email' && payload.channel !== 'sms') || !('payload' in payload)) {
    return NextResponse.json(
      {
        error: 'Expected shape: { channel: "email" | "sms", payload: {...} }',
      },
      { status: 400 }
    );
  }

  const result = await dispatchComms(payload as CommsDispatchRequest);
  const status = result.ok ? 200 : 502;

  return NextResponse.json(result, { status });
}
