import http from 'k6/http';
import { check } from 'k6';
import { Rate } from 'k6/metrics';

const baseUrl = __ENV.K6_BASE_URL || 'http://localhost:8080/api';
const serverErrorRate = new Rate('hpa_server_error_rate');

// Run this alongside `kubectl get hpa -w` and `kubectl top pods`. It produces
// load only; the evidence script records whether an actual scale-up occurred.
export const options = {
  scenarios: {
    scale_api: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: __ENV.K6_RAMP_UP || '1m', target: Number(__ENV.K6_TARGET_VUS || 60) },
        { duration: __ENV.K6_HOLD || '5m', target: Number(__ENV.K6_TARGET_VUS || 60) },
        { duration: __ENV.K6_RAMP_DOWN || '1m', target: 0 },
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    hpa_server_error_rate: ['rate<0.10'],
  },
};

export default function () {
  const tenant = `hpa-${__VU}-${__ITER}`;
  const response = http.post(
    `${baseUrl}/pay`,
    JSON.stringify({ amount: 10, currency: 'USD', tenant_id: tenant }),
    { headers: { 'Content-Type': 'application/json', 'X-Tenant': tenant }, tags: { scenario: 'hpa' } },
  );

  serverErrorRate.add(response.status >= 500 || response.status === 0);
  check(response, { 'request reached the API': (result) => result.status > 0 });
}
