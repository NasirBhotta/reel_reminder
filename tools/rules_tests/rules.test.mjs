import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp } from 'firebase/firestore';
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-reel-reminder', firestore: {
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080,
  }});
});
beforeEach(async () => env.clearFirestore());
after(async () => env?.cleanup());
const item = () => ({userId:'alice', url:'https://youtu.be/abc', sharedText:null, title:null,
  thumbnailUrl:null, platform:'youtube', createdAt:serverTimestamp(), updatedAt:serverTimestamp(),
  clientCreatedAt:Timestamp.now(), isFavorite:false});
const ref = (user, owner = 'alice') => doc(env.authenticatedContext(user).firestore(), `users/${owner}/saved_items/item`);
test('owner can create, read, favorite, and delete', async () => {
  const target = ref('alice');
  await assertSucceeds(setDoc(target, item()));
  await assertSucceeds(getDoc(target));
  await assertSucceeds(updateDoc(target, {isFavorite:true, updatedAt:serverTimestamp()}));
  await assertSucceeds(deleteDoc(target));
});
test('other accounts cannot read, write, update, or delete', async () => {
  await assertSucceeds(setDoc(ref('alice'), item()));
  const target = ref('bob');
  await assertFails(getDoc(target)); await assertFails(setDoc(target, item()));
  await assertFails(updateDoc(target, {isFavorite:true, updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(target));
});
test('anonymous access and forged ownership are rejected', async () => {
  const anonymous = doc(env.unauthenticatedContext().firestore(), 'users/alice/saved_items/item');
  await assertFails(getDoc(anonymous)); await assertFails(setDoc(anonymous, item()));
  await assertFails(setDoc(ref('alice'), {...item(), userId:'bob'}));
});
test('invalid schema and altered creation timestamps are rejected', async () => {
  await assertFails(setDoc(ref('alice'), {...item(), unexpected:true}));
  await assertFails(setDoc(ref('alice'), {...item(), url:'javascript:alert(1)'}));
  await assertSucceeds(setDoc(ref('alice'), item()));
  await assertFails(updateDoc(ref('alice'), {createdAt:serverTimestamp(), updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref('alice'), {userId:'bob', updatedAt:serverTimestamp()}));
});
test('free profile creation allowed; client cannot grant pro', async () => {
  const profile = doc(env.authenticatedContext('alice').firestore(), 'users/alice');
  await assertFails(setDoc(profile, {plan:'pro'}));
  await assertSucceeds(setDoc(profile, {plan:'free'}));
  await assertFails(updateDoc(profile, {plan:'pro'}));
});
