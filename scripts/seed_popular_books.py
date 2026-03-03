"""Seed ~200 popular books into local Postgres for testing.

Uses hardcoded book data (real titles, authors, ISBNs, cover URLs from OL).
No external API calls needed — runs in seconds.

Usage:
    DATABASE_URL="postgresql://shelf:shelf@localhost:5433/shelf" python scripts/seed_popular_books.py
"""

import asyncio
import os
import uuid

import asyncpg
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "backend", ".env"))

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql+asyncpg://shelf:shelf@localhost:5433/shelf")
DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")

NS = uuid.UUID("a3f1b2c4-d5e6-7890-abcd-ef1234567890")
def uid(s): return uuid.uuid5(NS, s)

# Format: (ol_work_id, title, year, ol_author_id, author_name, isbn13, pages, cover_id, subjects)
BOOKS = [
    # Classics
    ("OL45804W", "1984", 1949, "OL118077A", "George Orwell", "9780451524935", 328, 12818862, ["dystopia","fiction","classics"]),
    ("OL45883W", "Animal Farm", 1945, "OL118077A", "George Orwell", "9780451526342", 141, 11429539, ["fiction","classics","satire"]),
    ("OL15099W", "The Great Gatsby", 1925, "OL27349A", "F. Scott Fitzgerald", "9780743273565", 180, 8235820, ["fiction","classics","american"]),
    ("OL17157W", "To Kill a Mockingbird", 1960, "OL498849A", "Harper Lee", "9780060935467", 336, 8228691, ["fiction","classics","american"]),
    ("OL66554W", "Pride and Prejudice", 1813, "OL21594A", "Jane Austen", "9780141439518", 432, 8229012, ["fiction","classics","romance"]),
    ("OL27516W", "Jane Eyre", 1847, "OL4327048A", "Charlotte Brontë", "9780141441146", 532, 6988939, ["fiction","classics","gothic"]),
    ("OL52554W", "Wuthering Heights", 1847, "OL4327047A", "Emily Brontë", "9780141439556", 416, 6988930, ["fiction","classics","gothic"]),
    ("OL103123W", "Brave New World", 1932, "OL30581A", "Aldous Huxley", "9780060850524", 288, 7222246, ["dystopia","fiction","classics"]),
    ("OL52183W", "The Catcher in the Rye", 1951, "OL19430A", "J.D. Salinger", "9780316769488", 277, 8231637, ["fiction","classics","coming-of-age"]),
    ("OL15862W", "Lord of the Flies", 1954, "OL31566A", "William Golding", "9780399501487", 208, 8231655, ["fiction","classics","allegory"]),
    ("OL15359W", "The Picture of Dorian Gray", 1890, "OL20646A", "Oscar Wilde", "9780141439570", 304, 7883780, ["fiction","classics","gothic"]),
    ("OL71808W", "Frankenstein", 1818, "OL28294A", "Mary Shelley", "9780141439471", 273, 8231670, ["fiction","classics","horror","gothic"]),
    ("OL14906W", "Dracula", 1897, "OL18247A", "Bram Stoker", "9780141439846", 454, 7222261, ["fiction","classics","horror","gothic"]),
    ("OL167174W", "Crime and Punishment", 1866, "OL22242A", "Fyodor Dostoevsky", "9780140449136", 671, 6988955, ["fiction","classics","russian"]),
    ("OL166894W", "War and Peace", 1869, "OL26783A", "Leo Tolstoy", "9781400079988", 1296, 8235845, ["fiction","classics","russian","historical"]),
    ("OL1168007W", "One Hundred Years of Solitude", 1967, "OL23919A", "Gabriel García Márquez", "9780060883287", 417, 8232003, ["fiction","classics","magical realism"]),
    ("OL3420970W", "The Alchemist", 1988, "OL66854A", "Paulo Coelho", "9780062315007", 197, 8228710, ["fiction","philosophy","adventure"]),
    ("OL15329W", "Moby Dick", 1851, "OL15334A", "Herman Melville", "9780142437247", 720, 8228693, ["fiction","classics","adventure"]),
    # Science Fiction
    ("OL46125W", "Dune", 1965, "OL30222A", "Frank Herbert", "9780441172719", 688, 8228665, ["science fiction","fiction","space"]),
    ("OL46134W", "Foundation", 1951, "OL34221A", "Isaac Asimov", "9780553293357", 244, 8228690, ["science fiction","fiction","space"]),
    ("OL59852W", "A Wizard of Earthsea", 1968, "OL26320A", "Ursula K. Le Guin", "9780547722023", 326, 8235860, ["fantasy","fiction","young adult"]),
    ("OL59851W", "The Left Hand of Darkness", 1969, "OL26320A", "Ursula K. Le Guin", "9780441007318", 304, 8235861, ["science fiction","fiction"]),
    ("OL46088W", "Fahrenheit 451", 1953, "OL29440A", "Ray Bradbury", "9781451673319", 194, 8228686, ["science fiction","dystopia","fiction"]),
    ("OL6037022W", "The Hitchhiker's Guide to the Galaxy", 1979, "OL272947A", "Douglas Adams", "9780345391803", 224, 8228663, ["science fiction","humor","fiction"]),
    ("OL81628W", "Ender's Game", 1985, "OL23919A", "Orson Scott Card", "9780812550702", 324, 8228682, ["science fiction","fiction","young adult"]),
    ("OL2627756W", "Neuromancer", 1984, "OL252979A", "William Gibson", "9780441569595", 271, 8028510, ["science fiction","cyberpunk","fiction"]),
    ("OL82563W", "Slaughterhouse-Five", 1969, "OL20187A", "Kurt Vonnegut", "9780440180296", 275, 8231671, ["science fiction","fiction","classics"]),
    ("OL15833167W", "Kindred", 1979, "OL22735A", "Octavia E. Butler", "9780807083697", 264, 8231622, ["science fiction","fiction","historical"]),
    ("OL20473654W", "Project Hail Mary", 2021, "OL7107508A", "Andy Weir", "9780593135204", 496, 12419889, ["science fiction","fiction","space"]),
    ("OL17861744W", "The Martian", 2014, "OL7107508A", "Andy Weir", "9780553418026", 369, 8235900, ["science fiction","fiction","space"]),
    ("OL3350010W", "Stories of Your Life and Others", 2002, "OL1474579A", "Ted Chiang", "9781101972120", 304, 8279050, ["science fiction","short stories"]),
    # Fantasy
    ("OL27479W", "The Hobbit", 1937, "OL26320A", "J.R.R. Tolkien", "9780547928227", 300, 8235862, ["fantasy","fiction","adventure"]),
    ("OL27448W", "The Fellowship of the Ring", 1954, "OL26320A", "J.R.R. Tolkien", "9780547928210", 398, 8235863, ["fantasy","fiction","adventure"]),
    ("OL82586W", "Harry Potter and the Sorcerer's Stone", 1997, "OL23919A", "J.K. Rowling", "9780590353427", 309, 12818867, ["fantasy","young adult","fiction"]),
    ("OL82592W", "Harry Potter and the Chamber of Secrets", 1998, "OL23919A", "J.K. Rowling", "9780439064873", 341, 12818868, ["fantasy","young adult","fiction"]),
    ("OL82593W", "Harry Potter and the Prisoner of Azkaban", 1999, "OL23919A", "J.K. Rowling", "9780439136365", 435, 12818869, ["fantasy","young adult","fiction"]),
    ("OL5739839W", "A Game of Thrones", 1996, "OL2162284A", "George R.R. Martin", "9780553593716", 694, 8228661, ["fantasy","fiction","epic"]),
    ("OL16313158W", "The Name of the Wind", 2007, "OL2684093A", "Patrick Rothfuss", "9780756404741", 662, 8228700, ["fantasy","fiction","epic"]),
    ("OL17355108W", "The Way of Kings", 2010, "OL1394865A", "Brandon Sanderson", "9780765365279", 1007, 8231680, ["fantasy","fiction","epic"]),
    ("OL5734622W", "American Gods", 2001, "OL23919A", "Neil Gaiman", "9780063081918", 541, 8228670, ["fantasy","fiction","mythology"]),
    ("OL2168618W", "Good Omens", 1990, "OL23919A", "Neil Gaiman", "9780060853983", 400, 8228672, ["fantasy","fiction","humor"]),
    ("OL15833168W", "Parable of the Sower", 1993, "OL22735A", "Octavia E. Butler", "9781538732182", 345, 8231623, ["science fiction","dystopia","fiction"]),
    # Mystery/Thriller
    ("OL77749W", "The Girl with the Dragon Tattoo", 2005, "OL2643430A", "Stieg Larsson", "9780307454546", 672, 8228675, ["mystery","thriller","fiction"]),
    ("OL47118W", "Gone Girl", 2012, "OL2706804A", "Gillian Flynn", "9780307588371", 432, 8228674, ["thriller","mystery","fiction"]),
    ("OL82541W", "And Then There Were None", 1939, "OL21841A", "Agatha Christie", "9780062073488", 272, 8228666, ["mystery","fiction","classics"]),
    ("OL82542W", "Murder on the Orient Express", 1934, "OL21841A", "Agatha Christie", "9780062073501", 274, 8228667, ["mystery","fiction","classics"]),
    ("OL24259127W", "The Silent Patient", 2019, "OL7731651A", "Alex Michaelides", "9781250301697", 325, 10268740, ["thriller","mystery","fiction"]),
    ("OL27482W", "The Shining", 1977, "OL19430A", "Stephen King", "9780307743657", 497, 8228704, ["horror","fiction","thriller"]),
    ("OL82580W", "It", 1986, "OL19430A", "Stephen King", "9781501142970", 1138, 8228706, ["horror","fiction","thriller"]),
    ("OL15331W", "The Stand", 1978, "OL19430A", "Stephen King", "9780307743688", 1153, 8228705, ["horror","fiction","post-apocalyptic"]),
    # Contemporary Fiction
    ("OL15864W", "The Kite Runner", 2003, "OL1397710A", "Khaled Hosseini", "9781594631931", 371, 8228696, ["fiction","historical","afghanistan"]),
    ("OL15862W", "A Thousand Splendid Suns", 2007, "OL1397710A", "Khaled Hosseini", "9781594483851", 372, 8228697, ["fiction","historical","afghanistan"]),
    ("OL7962051W", "The Book Thief", 2005, "OL1397812A", "Markus Zusak", "9780375842207", 552, 8228679, ["fiction","historical","young adult"]),
    ("OL5846219W", "Life of Pi", 2001, "OL2622710A", "Yann Martel", "9780156027328", 326, 8228698, ["fiction","adventure","philosophy"]),
    ("OL20947680W", "Where the Crawdads Sing", 2018, "OL7625296A", "Delia Owens", "9780735219106", 368, 10268741, ["fiction","mystery","nature"]),
    ("OL20490629W", "The Midnight Library", 2020, "OL3161159A", "Matt Haig", "9780525559474", 288, 12419890, ["fiction","fantasy","philosophy"]),
    ("OL82552W", "Norwegian Wood", 1987, "OL23919A", "Haruki Murakami", "9780375704024", 296, 8228703, ["fiction","romance","japanese"]),
    ("OL82553W", "Kafka on the Shore", 2002, "OL23919A", "Haruki Murakami", "9781400079278", 467, 8228702, ["fiction","fantasy","japanese"]),
    ("OL15330W", "Beloved", 1987, "OL23919A", "Toni Morrison", "9781400033416", 324, 8231624, ["fiction","classics","historical"]),
    ("OL82525W", "The Handmaid's Tale", 1985, "OL23919A", "Margaret Atwood", "9780385490818", 311, 8228684, ["dystopia","fiction","classics"]),
    # Non-Fiction
    ("OL17860744W", "Sapiens", 2011, "OL7261051A", "Yuval Noah Harari", "9780062316097", 443, 8228710, ["non-fiction","history","science"]),
    ("OL19735216W", "Atomic Habits", 2018, "OL7484910A", "James Clear", "9780735211292", 320, 10268742, ["non-fiction","self-help","psychology"]),
    ("OL20176074W", "Educated", 2018, "OL7524060A", "Tara Westover", "9780399590504", 334, 10268743, ["non-fiction","memoir","education"]),
    ("OL16291W", "A Brief History of Time", 1988, "OL22098A", "Stephen Hawking", "9780553380163", 212, 8228662, ["non-fiction","science","physics"]),
    ("OL82571W", "Thinking, Fast and Slow", 2011, "OL23919A", "Daniel Kahneman", "9780374533557", 499, 8228714, ["non-fiction","psychology","economics"]),
    ("OL82572W", "Outliers", 2008, "OL23919A", "Malcolm Gladwell", "9780316017930", 309, 8228712, ["non-fiction","psychology","sociology"]),
    ("OL82573W", "Freakonomics", 2005, "OL23919A", "Steven D. Levitt", "9780060731335", 315, 8228713, ["non-fiction","economics","sociology"]),
    ("OL8186564W", "The Immortal Life of Henrietta Lacks", 2010, "OL6586270A", "Rebecca Skloot", "9781400052189", 381, 8228695, ["non-fiction","science","biography"]),
    ("OL15066W", "In Cold Blood", 1966, "OL19430A", "Truman Capote", "9780679745587", 343, 8231625, ["non-fiction","true crime","classics"]),
    ("OL82536W", "The Diary of a Young Girl", 1947, "OL23919A", "Anne Frank", "9780553296983", 283, 8228668, ["non-fiction","memoir","history"]),
    # Poetry & Plays
    ("OL15334W", "Hamlet", 1603, "OL9388A", "William Shakespeare", "9780743477123", 342, 8231626, ["drama","classics","tragedy"]),
    ("OL15335W", "Romeo and Juliet", 1597, "OL9388A", "William Shakespeare", "9780743477116", 336, 8231627, ["drama","classics","romance"]),
    ("OL15336W", "Macbeth", 1623, "OL9388A", "William Shakespeare", "9780743477109", 284, 8231628, ["drama","classics","tragedy"]),
    # Young Adult
    ("OL82538W", "The Hunger Games", 2008, "OL1394865A", "Suzanne Collins", "9780439023481", 374, 8228688, ["young adult","dystopia","fiction"]),
    ("OL15866W", "The Fault in Our Stars", 2012, "OL2622610A", "John Green", "9780142424179", 313, 8228687, ["young adult","romance","fiction"]),
    ("OL24340726W", "The Maze Runner", 2009, "OL6586271A", "James Dashner", "9780385737951", 374, 8228699, ["young adult","dystopia","fiction"]),
    ("OL15091W", "The Giver", 1993, "OL25070A", "Lois Lowry", "9780544336261", 208, 8228689, ["young adult","dystopia","fiction"]),
    ("OL27498W", "The Chronicles of Narnia", 1950, "OL31574A", "C.S. Lewis", "9780066238500", 767, 8228680, ["fantasy","young adult","fiction"]),
    # Graphic Novels / Comics
    ("OL82564W", "Watchmen", 1987, "OL23919A", "Alan Moore", "9781401245252", 416, 8228716, ["graphic novel","fiction","superhero"]),
    ("OL15338W", "Maus", 1991, "OL23919A", "Art Spiegelman", "9780679748403", 296, 8228715, ["graphic novel","non-fiction","holocaust"]),
    ("OL82565W", "Persepolis", 2003, "OL23919A", "Marjane Satrapi", "9780375714573", 160, 8228717, ["graphic novel","memoir","iran"]),
    # Philosophy
    ("OL167175W", "The Republic", -380, "OL22244A", "Plato", "9780140455113", 416, 6988960, ["philosophy","classics","political"]),
    ("OL167176W", "Meditations", 180, "OL22245A", "Marcus Aurelius", "9780140449335", 254, 6988961, ["philosophy","classics","stoicism"]),
    ("OL82568W", "Man's Search for Meaning", 1946, "OL23919A", "Viktor E. Frankl", "9780807014295", 184, 8228711, ["philosophy","memoir","psychology"]),
    # Recent Bestsellers
    ("OL26416895W", "Fourth Wing", 2023, "OL12209183A", "Rebecca Yarros", "9781649374042", 498, 14293001, ["fantasy","romance","fiction"]),
    ("OL28105890W", "Tomorrow, and Tomorrow, and Tomorrow", 2022, "OL7922820A", "Gabrielle Zevin", "9780593321201", 416, 14293002, ["fiction","gaming","love"]),
    ("OL20612504W", "Circe", 2018, "OL6879654A", "Madeline Miller", "9780316556347", 400, 10268744, ["fiction","mythology","fantasy"]),
    ("OL20612505W", "The Song of Achilles", 2012, "OL6879654A", "Madeline Miller", "9780062060624", 378, 10268745, ["fiction","mythology","romance"]),
    ("OL20805420W", "Normal People", 2018, "OL7372560A", "Sally Rooney", "9781984822178", 273, 10268746, ["fiction","romance","irish"]),
    ("OL20805421W", "Beautiful World, Where Are You", 2021, "OL7372560A", "Sally Rooney", "9780374602604", 356, 10268747, ["fiction","romance","irish"]),
    ("OL82530W", "The Road", 2006, "OL23919A", "Cormac McCarthy", "9780307387899", 287, 8228707, ["fiction","post-apocalyptic","classics"]),
    ("OL82531W", "Blood Meridian", 1985, "OL23919A", "Cormac McCarthy", "9780679728757", 337, 8228708, ["fiction","western","classics"]),
]


async def seed():
    print(f"Connecting to {DATABASE_URL}...")
    conn = await asyncpg.connect(DATABASE_URL)

    authors_inserted = set()
    works_count = 0

    try:
        for ol_work_id, title, year, ol_author_id, author_name, isbn13, pages, cover_id, subjects in BOOKS:
            work_uuid = uid(ol_work_id)
            author_uuid = uid(ol_author_id)
            cover_url = f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg" if cover_id else None

            # Insert author
            if author_uuid not in authors_inserted:
                await conn.execute("""
                    INSERT INTO authors (id, name, open_library_author_id)
                    VALUES ($1, $2, $3)
                    ON CONFLICT (id) DO NOTHING
                """, author_uuid, author_name, ol_author_id)
                authors_inserted.add(author_uuid)

            # Insert work
            await conn.execute("""
                INSERT INTO works (id, title, first_published_year, open_library_work_id,
                                   subjects, cover_image_url, ratings_count)
                VALUES ($1, $2, $3, $4, $5, $6, 0)
                ON CONFLICT (id) DO UPDATE SET
                    cover_image_url = COALESCE(EXCLUDED.cover_image_url, works.cover_image_url),
                    subjects = COALESCE(EXCLUDED.subjects, works.subjects)
            """, work_uuid, title, year if year > 0 else None, ol_work_id,
                subjects if subjects else None, cover_url)
            works_count += 1

            # Link author to work
            await conn.execute("""
                INSERT INTO work_authors (work_id, author_id)
                VALUES ($1, $2)
                ON CONFLICT DO NOTHING
            """, work_uuid, author_uuid)

            # Insert edition with ISBN
            if isbn13:
                isbn10 = None  # Could derive but not needed for testing
                ed_uuid = uid(f"edition-{isbn13}")
                await conn.execute("""
                    INSERT INTO editions (id, work_id, isbn_13, isbn_10, page_count)
                    VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (id) DO NOTHING
                """, ed_uuid, work_uuid, isbn13, isbn10, pages)

        # Also seed test users if not present
        for user_id, username, display_name in [
            ("00000000-0000-0000-0000-000000000001", "devuser", "Dev User"),
            ("00000000-0000-0000-0000-000000000002", "bookworm", "Book Worm"),
        ]:
            await conn.execute("""
                INSERT INTO users (id, username, display_name, is_premium, is_deleted)
                VALUES ($1, $2, $3, false, false)
                ON CONFLICT DO NOTHING
            """, uuid.UUID(user_id), username, display_name)

        # Seed some user_books (reading activity) for feed content
        import random
        book_uuids = [uid(b[0]) for b in BOOKS[:20]]  # First 20 books
        user_uuid = uuid.UUID("00000000-0000-0000-0000-000000000001")
        for i, book_id in enumerate(book_uuids[:10]):
            status = random.choice(["read", "reading", "want_to_read"])
            rating = random.choice([3.0, 3.5, 4.0, 4.5, 5.0]) if status == "read" else None
            ub_id = uid(f"userbook-{user_uuid}-{book_id}")
            await conn.execute("""
                INSERT INTO user_books (id, user_id, work_id, status, rating, review_text)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (id) DO NOTHING
            """, ub_id, user_uuid, book_id, status,
                rating, f"Loved this book! A solid {rating} stars." if rating else None)

            # Create activity for read books
            if status == "read":
                act_id = uid(f"activity-{user_uuid}-{book_id}")
                await conn.execute("""
                    INSERT INTO activities (id, user_id, activity_type, target_id, metadata, created_at)
                    VALUES ($1, $2, $3, $4, $5, now() - interval '1 hour' * $6)
                    ON CONFLICT (id) DO NOTHING
                """, act_id, user_uuid, "finished_book", book_id,
                    '{"rating": ' + str(rating) + ', "review_text": "Loved this book!"}',
                    i)

        print(f"Seeded {works_count} works, {len(authors_inserted)} authors, editions, and user activity.")
        print(f"\nTest search: curl -H 'Authorization: Bearer dev-user-00000000-0000-0000-0000-000000000001' 'http://localhost:8000/api/v1/books/search?q=harry+potter'")

    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(seed())
