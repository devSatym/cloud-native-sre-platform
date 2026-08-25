import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const baseUrl = __ENV.K6_BASE_URL || 'http://localhost:8080/api';
const errorRate = new Rate('payment_error_rate');
const paymentLatency = new Trend('payment_latency', true);

export const options = {
  scenarios: {
    baseline: {
      executor: 'constant-vus',
      vus: Number(__ENV.K6_VUS || 5),
      duration: __ENV.K6_DURATION || '1m',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<500'],
    payment_error_rate: ['rate<0.02'],
  },
};

export default function () {
  const response = http.post(
    `${baseUrl}/pay`,
    JSON.stringify({ amount: 10, currency: 'USD', tenant_id: `baseline-${__VU}-${__ITER}` }),
    {
      headers: { 'Content-Type': 'application/json', 'X-Tenant': `baseline-${__VU}-${__ITER}` },
      tags: { scenario: 'baseline' },
    },
  );

  paymentLatency.add(response.timings.duration);
  errorRate.add(response.status >= 500 || response.status === 0);
  check(response, { 'payment accepted': (result) => result.status === 201 });
  sleep(0.1);
}
