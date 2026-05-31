db.getSiblingDB("unifi").createUser({
  user: "unifi",
  pwd: process.env.MONGO_PASS,
  roles: [{ role: "readWrite", db: "unifi" }],
});

db.getSiblingDB("unifi_stat").createUser({
  user: "unifi",
  pwd: process.env.MONGO_PASS,
  roles: [{ role: "readWrite", db: "unifi_stat" }],
});
