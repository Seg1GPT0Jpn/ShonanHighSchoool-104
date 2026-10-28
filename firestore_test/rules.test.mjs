import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, writeBatch, increment, deleteDoc, getDocs, collection, deleteField } from 'firebase/firestore';
import { readFileSync } from 'fs';
import { test, beforeAll, afterAll, beforeEach, expect } from 'vitest';

let env;
const K = '2026_前期期末_現代の国語';
beforeAll(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-shonan', firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 } });
});
afterAll(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const member = (uid) => env.authenticatedContext(uid, { email: uid + '@example-school.ed.jp', email_verified: true }).firestore();
const outsider = (uid) => env.authenticatedContext(uid, { email: uid + '@gmail.com', email_verified: true }).firestore();
const bk = (b) => 'b' + String(b).padStart(2, '0');

function join(db, uid, b) {
  const w = writeBatch(db);
  w.set(doc(db, 'entries', K, 'users', uid), { b });
  w.set(doc(db, 'hist', K), { total: increment(1), [bk(b)]: increment(1) }, { merge: true });
  return w.commit();
}
function move(db, uid, a, b) {
  const w = writeBatch(db);
  w.set(doc(db, 'entries', K, 'users', uid), { b });
  w.set(doc(db, 'hist', K), { [bk(a)]: increment(-1), [bk(b)]: increment(1) }, { merge: true });
  return w.commit();
}
function leave(db, uid, b) {
  const w = writeBatch(db);
  w.delete(doc(db, 'entries', K, 'users', uid));
  w.set(doc(db, 'hist', K), { total: increment(-1), [bk(b)]: increment(-1) }, { merge: true });
  return w.commit();
}

test('学校アカウントは参加・変更・取り消しができる', async () => {
  const db = member('u1');
  await assertSucceeds(join(db, 'u1', 8));
  await assertSucceeds(move(db, 'u1', 8, 12));
  await assertSucceeds(leave(db, 'u1', 12));
});

test('学校外のアカウントは参加できない', async () => {
  await assertFails(join(outsider('x'), 'x', 8));
});

test('1人で2回参加して人数を水増しできない', async () => {
  const db = member('u1');
  await assertSucceeds(join(db, 'u1', 8));
  await assertFails(join(db, 'u1', 8));
});

test('hist だけを書き換えることはできない', async () => {
  const db = member('u1');
  await assertSucceeds(join(db, 'u1', 8));
  await assertFails(setDoc(doc(db, 'hist', K), { total: increment(5), b20: increment(5) }, { merge: true }));
  await assertFails(setDoc(doc(db, 'hist', K), { b03: increment(1) }, { merge: true }));
});

test('記録だけを書いて hist を動かさないことはできない', async () => {
  await assertFails(setDoc(doc(member('u1'), 'entries', K, 'users', 'u1'), { b: 8 }));
});

test('他人の区間とずれた増やし方はできない', async () => {
  const db = member('u1');
  const w = writeBatch(db);
  w.set(doc(db, 'entries', K, 'users', 'u1'), { b: 8 });
  w.set(doc(db, 'hist', K), { total: increment(1), b20: increment(1) }, { merge: true });
  await assertFails(w.commit());
});

test('他人の記録は読めず、一覧もとれない', async () => {
  await assertSucceeds(join(member('u1'), 'u1', 8));
  await assertSucceeds(getDoc(doc(member('u1'), 'entries', K, 'users', 'u1')));
  await assertFails(getDoc(doc(member('u2'), 'entries', K, 'users', 'u1')));
  await assertFails(getDocs(collection(member('u2'), 'entries', K, 'users')));
});

test('点数そのものや名前など、区間以外は保存できない', async () => {
  const db = member('u1');
  const w = writeBatch(db);
  w.set(doc(db, 'entries', K, 'users', 'u1'), { b: 8, score: 42, name: 'x' });
  w.set(doc(db, 'hist', K), { total: increment(1), b08: increment(1) }, { merge: true });
  await assertFails(w.commit());
});

test('分布は20人未満では誰も読めず、20人以上で学校アカウントだけ読める', async () => {
  for (let i = 0; i < 19; i++) await assertSucceeds(join(member('u' + i), 'u' + i, i % 21));
  await assertFails(getDoc(doc(member('u0'), 'hist', K)));
  await assertSucceeds(join(member('u19'), 'u19', 10));
  const s = await assertSucceeds(getDoc(doc(member('u0'), 'hist', K)));
  expect(s.data().total).toBe(20);
  await assertFails(getDoc(doc(outsider('x'), 'hist', K)));
  await assertFails(getDocs(collection(member('u0'), 'hist')));
});

test('アプリと同じ書き方（total を0だけ動かす変更も含む）で通る', async () => {
  const db = member('u1');
  const w = writeBatch(db);
  w.set(doc(db, 'entries', K, 'users', 'u1'), { b: 8 });
  w.set(doc(db, 'hist', K), { total: increment(1), b08: increment(1) }, { merge: true });
  await assertSucceeds(w.commit());
  const w2 = writeBatch(db);
  w2.set(doc(db, 'entries', K, 'users', 'u1'), { b: 9 });
  w2.set(doc(db, 'hist', K), { total: increment(0), b08: increment(-1), b09: increment(1) }, { merge: true });
  await assertSucceeds(w2.commit());
});
