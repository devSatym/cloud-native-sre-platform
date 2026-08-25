import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const baseUrl = __ENV.K6_BASE_URL || 'http://localhost:8080/api';
const faultErrorRate = new Rate('latency_fault_server_error_rate');
const faultLatency = new Trend('latency_fault_duration', true);

// Apply the reversible slow/latency fault before this test. This script records
// observed behavior; it does not assert a fabricated outage percentage.
export const options = {
  scenarios: {
    latency_fault: {
      executor: 'constant-vus',
      vus: Number(__ENV.K6_VUS || 5),
      duration: __ENV.K6_DURATION || '2m',
    },
  },
};

export default function () {
  const tenant = `latency-fault-${__VU}-${__ITER}`;
  const response = http.post(
    `${baseUrl}/pay`,
    JSON.stringify({ amount: 10, currency: 'USD', tenant_id: tenant }),
    { headers: { 'Content-Type': 'application/json', 'X-Tenant': tenant }, tags: { scenario: 'latency_fault' } },
  );

  faultLatency.add(response.timings.duration);
  faultErrorRate.add(response.status >= 500 || response.status === 0);
  check(response, { 'response was received': (result) => result.status > 0 });
  sleep(0.1);
}
