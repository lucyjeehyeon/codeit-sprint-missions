-- 파트 1 

/*
1-1. 존재하는 테이블의 목록과, 각 테이블의 컬럼 정보를 각각 확인해 보세요.
테이블의 목록은 SHOW TABLES; 구문으로, 테이블의 컬럼 정보는 DESCRIBE 테이블_이름; 구문으로 확인할 수 있어요.
*/

SHOW TABLES;

DESCRIBE albums;
DESCRIBE artists;
DESCRIBE history;
DESCRIBE playlists;
DESCRIBE songs;
DESCRIBE users;

/*
1-2. 사용자 목록, 아티스트 목록을 각각 확인해 보세요.
*/

SELECT *
FROM users;

SELECT *
FROM artists;

/*
1-3. 궁금한 아티스트를 한 명 골라 모든 앨범 목록을 확인해 보세요.
*/

SELECT al.title
FROM artists ar
LEFT JOIN albums al
ON ar.id = al.artist_id
WHERE ar.name = 'Deanna Murphy';

SELECT title
FROM albums
WHERE artist_id = 35;

/*
1-4. 사용자를 한 명 골라 가장 최근에 재생한 20곡을 재생 시점 순으로 확인해 보세요.
(재생 시점, 사용자 ID, 사용자 계정명, 곡 ID, 곡 제목, 곡 재생 시간(초)를 조회해보세요.)
*/

SELECT h.played_at, h.user_id, u.username, h.song_id, s.title, s.duration_seconds
FROM users u
LEFT JOIN history h
ON u.id = h.user_id
LEFT JOIN songs s
ON h.song_id = s.id
WHERE u.username = 'danielblackwell'
ORDER BY h.played_at DESC
LIMIT 20;

-- 파트 2

/*
2-1. 2024년에 발매된 모든 앨범을 확인해 보세요.
(앨범의 ID, 앨범 제목, 앨범 발매일, 아티스트 이름을 조회해 보세요. 발매순으로 정렬하고 발매일이 같을 경우 앨범의 ID 순으로 정렬하세요.)
*/

SELECT a.id, a.title, a.release_date, ar.name
FROM albums a
LEFT JOIN artists ar
ON a.artist_id = ar.id
WHERE a.release_date LIKE '2024%'
ORDER BY a.release_date, a.id;

/*
2-2. 2024년에 앨범을 발매한 아티스트의 목록을 앨범을 많이 발매한 순서대로 확인해 보세요.
(아티스트 ID, 아티스트 이름, 발매한 앨범의 수를 조회하고, 앨범의 수가 많은 것부터 정렬하되 앨범의 수가 같을 경우 아티스트의 이름 순으로 정렬하세요.)
*/

SELECT ar.id, ar.name, COUNT(a.id) AS albumcount
FROM albums a
LEFT JOIN artists ar
ON a.artist_id = ar.id
WHERE release_date LIKE '2024%'
GROUP BY ar.id, ar.name
ORDER BY albumcount DESC, ar.name;

/*
2-3. 2024년에 가장 많이 재생된 20곡을 많이 재생된 순서대로 확인해 보세요.
(곡의 ID, 곡 제목, 재생 수를 조회하고, 재생 수가 같을 경우 곡 제목 순으로 정렬하세요.)
*/

SELECT s.id, s.title, COUNT(h.id) AS playcount
FROM history h
LEFT JOIN songs s
ON h.song_id = s.id
WHERE played_at LIKE '2024%'
GROUP BY s.id, s.title
ORDER BY playcount DESC, s.title
LIMIT 20;

/*
2-4. 2024년에 가장 많이 재생된 20명의 아티스트를 많이 재생된 순서대로 확인해 보세요.
(아티스트의 ID, 아티스트 이름, 재생 수를 조회하고, 재생 수가 같은 경우 아티스트의 이름 순으로 정렬하세요.)
*/

SELECT ar.id, ar.name, COUNT(h.id) AS playcount
FROM artists ar
LEFT JOIN albums a
ON ar.id = a.artist_id
LEFT JOIN songs s
ON a.id = s.album_id
LEFT JOIN history h
ON s.id = h.song_id
WHERE played_at LIKE '2024%'
GROUP BY ar.id, ar.name
ORDER BY playcount DESC, ar.name
LIMIT 20;

-- 파트 3 (특정 사용자 id: 16)

/*
3-1. 특정 사용자가 2024년에 재생한 곡 중에서 가장 최근에 재생한 100곡을 재생 시점 순으로 정렬하여 확인해 보세요.
(사용자 ID, 사용자 계정명, 재생 시점, 곡 제목, 앨범 제목, 아티스트 이름을 조회하세요.)
*/

SELECT u.id, u.username, h.played_at, s.title, a.title, ar.name
FROM history h
LEFT JOIN users u
ON h.user_id = u.id
LEFT JOIN songs s
ON h.song_id = s.id
LEFT JOIN albums a
ON a.id = s.album_id
LEFT JOIN artists ar
ON ar.id = a.artist_id
WHERE (u.id = 16) AND (h.played_at LIKE '2024%')
ORDER BY h.played_at DESC
LIMIT 100;

/*
3-2. 특정 사용자가 2024년에 많이 들은 20곡을 많이 들은 순서대로 확인해 보세요.
(곡의 ID, 곡 제목, 재생 수를 조회하시오. 재생 수가 같은 경우 곡 제목 순으로 정렬하세요.)
*/

SELECT s.id, s.title, COUNT(h.id) AS playcount
FROM history h
LEFT JOIN songs s
ON h.song_id = s.id
WHERE (h.user_id = 16) AND (h.played_at LIKE '2024%')
GROUP BY s.id, s.title
ORDER BY playcount DESC, s.title
LIMIT 20;

/*
3-3. 특정 사용자가 2024년에 많이 들은 20명의 아티스트를 많이 들은 순서대로 확인해 보세요.
(아티스트의 ID, 아티스트 이름, 재생 수를 조회하고, 재생 수가 같은 경우 아티스트의 이름 순으로 정렬하세요.)
*/

SELECT ar.id, ar.name, COUNT(h.id) AS playcount
FROM history h
LEFT JOIN songs s
ON h.song_id = s.id
LEFT JOIN albums a
ON s.album_id = a.id
LEFT JOIN artists ar
ON a.artist_id = ar.id
WHERE (h.user_id = 16) AND (h.played_at LIKE '2024%')
GROUP BY ar.id, ar.name
ORDER BY playcount DESC, ar.name
LIMIT 20;

/*
3-4. 특정 사용자의 2024년 월별 음악 감상 횟수를 확인해 보세요.
*/

SELECT MONTH(played_at) AS month, COUNT(id) AS playcount
FROM history
WHERE (user_id = 16) AND (played_at LIKE '2024%')
GROUP BY month
ORDER BY month;

/*
3-5. 특정 사용자가 2024년 재생한 곡들의 총 재생 시간을 확인해 보세요.
*/

SELECT SUM(s.duration_seconds) AS totalsec
FROM history h
LEFT JOIN songs s
ON h.song_id = s.id
WHERE (h.user_id = 16) AND (h.played_at LIKE '2024%');

/*
3-6. 특정 사용자가 2024년에 새롭게 발견한 아티스트 목록을 확인해 보세요.
*/

SELECT DISTINCT ar.name
FROM history h
LEFT JOIN songs s
ON h.song_id = s.id
LEFT JOIN albums a
ON s.album_id = a.id
LEFT JOIN artists ar
ON a.artist_id = ar.id
WHERE h.user_id = 21
  AND YEAR(h.played_at) = 2024
  AND ar.id NOT IN (
      SELECT DISTINCT ar2.id
      FROM history h2
      LEFT JOIN songs s2
      ON h2.song_id = s2.id
      LEFT JOIN albums a2
      ON s2.album_id = a2.id
      LEFT JOIN artists ar2
      ON a2.artist_id = ar2.id
      WHERE h2.user_id = 21
        AND YEAR(h2.played_at) <= 2023
  );

-- 파트 4 (특정 사용자 id: 21, 특정 아티스트 id: 195)

/*
4-1. 특정 사용자가 2024년에 특정 아티스트의 곡을 들은 사용자들 중에서 감상 횟수 기준으로 상위 몇 퍼센트(%)에 속하는지 확인해 보세요.
*/

SELECT userlist, top
FROM (SELECT userlist, (ROW_NUMBER() OVER (ORDER BY playcount DESC) / COUNT(*) OVER ()) * 100 AS top
    FROM (SELECT h.user_id AS userlist, COUNT(h.id) AS playcount
          FROM history h
          LEFT JOIN songs s
          ON h.song_id = s.id
          LEFT JOIN albums a
          ON s.album_id = a.id
          LEFT JOIN artists ar
          ON a.artist_id = ar.id
          WHERE (h.played_at LIKE '2024%') AND (ar.id = 195)
          GROUP BY h.user_id) AS t) AS t2
WHERE userlist = 21;

/*
4-2. 특정 사용자가 들은 곡 중 다른 사용자들은 많이 듣지 않는 곡을 찾아보세요.
(특정 사용자의 감상 횟수와 전체 사용자들의 평균 감상 횟수를 비교)
*/

SELECT t2.title, t2.playcount21, t3.avgplay
FROM (SELECT s.title AS title, COUNT(h.id) AS playcount21
           FROM history h
           LEFT JOIN songs s
           ON h.song_id = s.id
           WHERE h.user_id = 21
           GROUP BY title) AS t2
LEFT JOIN (SELECT title, AVG(playcount) AS avgplay
           FROM (SELECT h.user_id AS user, s.title AS title, COUNT(h.id) AS playcount
                 FROM history h
		         LEFT JOIN songs s
                 ON h.song_id = s.id
                 GROUP BY user, title) AS t
           GROUP BY title) AS t3
ON t2.title = t3.title
WHERE t2.playcount21 > t3.avgplay
ORDER BY (t2.playcount21 - t3.avgplay) DESC;

/*
4-3. 특정 사용자의 요일별 음악 재생 비율을 확인해 보세요.
*/

SELECT dayofweek, CONCAT((daycount / SUM(daycount) OVER()) * 100, '%') AS ratio
FROM (SELECT DAYOFWEEK(played_at) AS dayofweek, COUNT(id) AS daycount
      FROM history
      WHERE user_id = 21
      GROUP BY dayofweek) AS t
ORDER BY dayofweek;

/*
4-4. 특정 사용자의 시간대별 음악 재생 비율을 확인해 보세요.
*/

SELECT hour, CONCAT((hourcount / SUM(hourcount) OVER()) * 100, '%') AS ratio
FROM (SELECT HOUR(played_at) AS hour, COUNT(id) AS hourcount
      FROM history
      WHERE user_id = 21
      GROUP BY hour) AS t
ORDER BY hour;
