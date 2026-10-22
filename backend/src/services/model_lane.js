/** How many OpenAI/Gemini answers may run at once. The rest wait in their own lane. */
const MAX_OPEN = 40;
const MAX_QUEUE = 1000;
const WAIT_MS = 25000;

let open = 0;
const queue = [];

function pump() {
  while (open < MAX_OPEN && queue.length) {
    const job = queue.shift();
    if (!job || job.done) continue;
    job.done = true;
    clearTimeout(job.timer);
    open += 1;
    job.resolve(release);
  }
}

function release() {
  open = Math.max(0, open - 1);
  pump();
}

export function acquireModelSlot() {
  if (open < MAX_OPEN && queue.length === 0) {
    open += 1;
    return Promise.resolve(release);
  }
  if (queue.length >= MAX_QUEUE) {
    const err = new Error('busy');
    err.status = 503;
    return Promise.reject(err);
  }
  return new Promise((resolve, reject) => {
    const job = {
      done: false,
      resolve,
      reject,
      timer: setTimeout(() => {
        if (job.done) return;
        job.done = true;
        const index = queue.indexOf(job);
        if (index >= 0) queue.splice(index, 1);
        const err = new Error('busy');
        err.status = 503;
        reject(err);
      }, WAIT_MS),
    };
    queue.push(job);
    pump();
  });
}
