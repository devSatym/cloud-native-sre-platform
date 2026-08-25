import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate } from 'k6/metrics';

const baseUrl = __ENV.K6_BASE_URL || 'http://localhost:8080/api';
const observedServerErrors = new Counter('error_fault_server_errors');
const serverErrorRate = new Rate('error_fault_server_error_rate');

// Apply the reversible failure fault before this test. A non-zero 5xx count is
// evidence to capture, not a pre-filled result claimed by the repository.
export const options = {
  scenarios: {
    error_fault: {
      executor: 'constant-vus',
      vus: Number(__ENV.K6_VUS || 5),
      duration: __ENV.K6_DURATION || '2m',
    },
  },
};

export default function () {
  const tenant = `error-fault-${__VU}-${__ITER}`;
  const response = http.post(
    `${baseUrl}/pay`,
    JSON.stringify({ amount: 10, currency: 'USD', tenant_id: tenant }),
    { headers: { 'Content-Type': 'application/json', 'X-Tenant': tenant }, tags: { scenario: 'error_fault' } },
  );

  const serverError = response.status >= 500 || response.status === 0;
  if (serverError) {
    observedServerErrors.add(1);
  }
  serverErrorRate.add(serverError);
  check(response, { 'response was received': (result) => result.status > 0 });
  sleep(0.1);
}
