const fs = require('fs');
const assert = require('assert');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');

(async () => {
  // load rules from workspace firestore.rules
  const rulesPath = '../../firestore.rules';
  const rules = readFileSync(require('path').resolve(__dirname, rulesPath), 'utf8');

  const projectId = 'firestore-rules-test-project';
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });

  try {
    // Create authenticated contexts for alice, bob, charlie
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const charlie = testEnv.authenticatedContext('charlie');

    const aliceDb = alice.firestore();
    const bobDb = bob.firestore();
    const charlieDb = charlie.firestore();

    // Test A: alice can create valid private message
    const messageA = {
      senderUid: 'alice',
      participants: ['alice', 'bob'],
      conversationId: 'img:IMG123:alice_bob',
      text: 'Szia Bob',
      createdAt: { __serverTimestamp__: true }
    };

    console.log('Test A: alice create valid message -> expect allow');
    await assertSucceeds(aliceDb.collection('private_messages').doc('testA').set(messageA));
    console.log('  PASS');

    // Test B: bob tries to create with senderUid someoneElse -> expect deny
    const messageB = {
      senderUid: 'someoneElse',
      participants: ['bob', 'alice'],
      conversationId: 'img:IMG123:alice_bob',
      text: 'hamis',
      createdAt: { __serverTimestamp__: true }
    };
    console.log('Test B: bob create with wrong senderUid -> expect deny');
    await assertFails(bobDb.collection('private_messages').doc('testB').set(messageB));
    console.log('  PASS');

    // Test C: bob reads messageA -> expect allow
    console.log('Test C: bob get testA -> expect allow');
    await assertSucceeds(bobDb.collection('private_messages').doc('testA').get());
    console.log('  PASS');

    // Test D: charlie get testA -> expect deny
    console.log('Test D: charlie get testA -> expect deny');
    await assertFails(charlieDb.collection('private_messages').doc('testA').get());
    console.log('  PASS');

    // Test E: alice query by conversationId -> expect allow
    console.log('Test E: alice query by conversationId -> expect allow');
    const q = aliceDb.collection('private_messages').where('conversationId', '==', 'img:IMG123:alice_bob').orderBy('createdAt');
    await assertSucceeds(q.get());
    console.log('  PASS');

    console.log('All tests done.');
  } finally {
    await testEnv.cleanup();
  }
})().catch(err => {
  console.error('Test script failed:', err);
  process.exitCode = 1;
});
