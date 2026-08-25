import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate } from 'k6/metrics';

const baseUrl = __ENV.K6_BASE_URL || 'http://localhost:8080/api';
const limit = Number(__ENV.RATE_LIMIT_REQUESTS || 60);
const tenant = __ENV.RATE_LIMIT_TENANT || `rate-limit-evidence-${Date.now()}`;
const allowedResponses = new Counter('rate_limit_allowed_responses');
const deniedResponses = new Counter('rate_limit_denied_responses');
const sequenceFailures = new Rate('rate_limit_sequence_failures');

export const options = {
  vus: 1,
  iterations: Number(__ENV.RATE_LIMIT_ITERATIONS || limit + 1),
  thresholds: {
    rate_limit_sequence_failures: ['rate==0'],
    rate_limit_denied_responses: ['count>=1'],
  },
};

export default function () {
  const expectedStatus = __ITER < limit ? 201 : 429;
  const response = http.post(
    `${baseUrl}/pay`,
    JSON.stringify({ amount: 10, currency: 'USD', tenant_id: tenant }),
    { headers: { 'Content-Type': 'application/json', 'X-Tenant': tenant }, tags: { scenario: 'rate_limit' } },
  );

  if (response.status === 201) {
    allowedResponses.add(1);
  }
  if (response.status === 429) {
    deniedResponses.add(1);
  }

  const correctStatus = check(response, {
    [`request ${__ITER + 1} has expected status ${expectedStatus}`]: (result) =>
      result.status === expectedStatus,
  });
  sequenceFailures.add(!correctStatus);
}
