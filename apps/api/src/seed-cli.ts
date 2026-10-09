import { seedDemo } from './seed';
import { db } from './store';

seedDemo();
console.log(
  JSON.stringify(
    { events: db.events.length, conflicts: db.conflicts.length, users: db.users.length },
    null,
    2,
  ),
);
